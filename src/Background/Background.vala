//
//  Copyright (C) 2014 Tom Beckmann
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Gala {
    public class Background : Object {
        private const double ANIMATION_OPACITY_STEP_INCREMENT = 4.0;
        private const double ANIMATION_MIN_WAKEUP_INTERVAL = 1.0;

        public signal void changed ();
        public signal void loaded ();

        public Meta.Display display { get; construct; }
        public int monitor_index { get; construct; }
        public BackgroundSource background_source { get; construct; }
        public bool is_loaded { get; private set; default = false; }
        public GDesktop.BackgroundStyle style { get; construct; }
        public GLib.File? file { get; construct; }
        public Meta.Background background { get; private set; }

        private Animation? animation = null;
        private Gee.HashMap<GLib.File, ulong> file_watches;
        private Cancellable cancellable;
        private uint update_animation_timeout_id = 0;

        private Gnome.WallClock clock;
        private ulong clock_timezone_handler = 0;

        public Background (Meta.Display display, int monitor_index, GLib.File? file,
                BackgroundSource background_source, GDesktop.BackgroundStyle style) {
            Object (display: display,
                    monitor_index: monitor_index,
                    background_source: background_source,
                    style: style,
                    file: file);
        }

        construct {
            background = new Meta.Background (display);
            background.set_data<unowned Background> ("delegate", this);

            file_watches = new Gee.HashMap<GLib.File, ulong> ();
            cancellable = new Cancellable ();

            background_source.changed.connect (settings_changed);

            clock = new Gnome.WallClock ();
            clock_timezone_handler = clock.notify["timezone"].connect (() => {
                if (animation != null) {
                    load_animation.begin (animation.file);
                }
            });

            load ();
        }

        public void destroy () {
            cancellable.cancel ();
            remove_animation_timeout ();

            var cache = BackgroundCache.get_default ();

            foreach (var watch in file_watches.values) {
                SignalHandler.disconnect (cache, watch);
            }

            background_source.changed.disconnect (settings_changed);

            if (clock_timezone_handler != 0) {
                clock.disconnect (clock_timezone_handler);
            }
        }

        public void update_resolution () {
            if (animation != null) {
                remove_animation_timeout ();
                update_animation ();
            }
        }

        private void set_loaded () {
            if (is_loaded)
                return;

            is_loaded = true;

            Idle.add (() => {
                loaded ();
                return false;
            });
        }

        private void load_pattern () {
            string color_string;
            var settings = background_source.settings;

            color_string = settings.get_string ("primary-color");
            var color = Clutter.Color.from_string (color_string);

            var shading_type = settings.get_enum ("color-shading-type");

            if (shading_type == GDesktop.BackgroundShading.SOLID) {
                background.set_color (color);
            } else {
                color_string = settings.get_string ("secondary-color");
                var second_color = Clutter.Color.from_string (color_string);
                background.set_gradient ((GDesktop.BackgroundShading) shading_type, color, second_color);
            }
        }

        private void watch_file (GLib.File file) {
            if (file_watches.has_key (file))
                return;

            var cache = BackgroundCache.get_default ();

            cache.monitor_file (file);

            file_watches[file] = cache.file_changed.connect ((changed_file) => {
                if (changed_file == file) {
                    var image_cache = Meta.BackgroundImageCache.get_default ();
                    image_cache.purge (changed_file);
                    changed ();
                }
            });
        }

        private void remove_animation_timeout () {
            if (update_animation_timeout_id != 0) {
                Source.remove (update_animation_timeout_id);
                update_animation_timeout_id = 0;
            }
        }

        private void finish_animation (GLib.GenericArray<GLib.File> files) {
            set_loaded ();

            if (files.length > 1)
                background.set_blend (files[0], files[1], animation.transition_progress, style);
            else if (files.length > 0)
                background.set_file (files[0], style);
            else
                background.set_file (null, style);

            queue_update_animation ();
        }

        private void update_animation () {
            update_animation_timeout_id = 0;

            animation.update (display.get_monitor_geometry (monitor_index));
            var files = animation.key_frame_files;

            unowned var cache = Meta.BackgroundImageCache.get_default ();
            var num_pending_images = files.length;
            foreach (unowned var file in files) {
                watch_file (file);

                var image = cache.load (file);

                if (image.is_loaded ()) {
                    num_pending_images--;
                    if (num_pending_images == 0) {
                        finish_animation (files);
                    }
                } else {
                    ulong handler = 0;
                    handler = image.loaded.connect (() => {
                        SignalHandler.disconnect (image, handler);
                        if (--num_pending_images == 0) {
                            finish_animation (files);
                        }
                    });
                }
            }
        }

        private void queue_update_animation () {
            if (update_animation_timeout_id != 0)
                return;

            if (cancellable == null || cancellable.is_cancelled ())
                return;

            if (animation.transition_duration == 0)
                return;

            var n_steps = 255.0 / ANIMATION_OPACITY_STEP_INCREMENT;
            var time_per_step = (animation.transition_duration * 1000) / n_steps;

            var interval = (uint32) Math.fmax (ANIMATION_MIN_WAKEUP_INTERVAL * 1000, time_per_step);

            if (interval > uint32.MAX)
                return;

            update_animation_timeout_id = Timeout.add (interval, () => {
                update_animation_timeout_id = 0;
                update_animation ();
                return false;
            });
        }

        private async void load_animation (GLib.File file) {
            animation = yield BackgroundCache.get_default ().get_animation (file);

            if (animation == null || cancellable.is_cancelled ()) {
                set_loaded ();
                return;
            }

            update_animation ();
            watch_file (file);
        }

        private void load_image (GLib.File file) {
            background.set_file (file, style);
            watch_file (file);

            var cache = Meta.BackgroundImageCache.get_default ();
            var image = cache.load (file);
            if (image.is_loaded ())
                set_loaded ();
            else {
                ulong handler = 0;
                handler = image.loaded.connect (() => {
                    set_loaded ();
                    SignalHandler.disconnect (image, handler);
                });
            }
        }

        private inline void load_file (GLib.File file) {
            if (file.get_basename ().has_suffix (".xml")) {
                load_animation.begin (file);
            } else {
                load_image (file);
            }
        }

        private void load () {
            load_pattern ();

            if (file == null) {
                set_loaded ();
            } else {
                load_file (file);
            }
        }

        private void settings_changed () {
            changed ();
        }
    }
}
