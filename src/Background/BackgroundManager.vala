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
    public class BackgroundManager : Meta.BackgroundGroup {
        private const string GNOME_BACKGROUND_SCHEMA = "org.gnome.desktop.background";
        private const string GALA_BACKGROUND_SCHEMA = "io.elementary.desktop.background";
        private const string DIM_WALLPAPER_KEY = "dim-wallpaper-in-dark-style";
        private const double DIM_OPACITY = 0.55;
        private const int FADE_ANIMATION_TIME = 1000;

        public signal void changed ();

        public Meta.Display display { get; construct; }
        public int monitor_index { get; construct; }
        public bool control_position { get; construct; }

        private BackgroundSource background_source;
        private Meta.BackgroundActor background_actor;
        private Meta.BackgroundActor? new_background_actor = null;

        private Clutter.PropertyTransition? last_dim_transition = null;

        private static Settings gala_background_settings;

        public BackgroundManager (Meta.Display display, int monitor_index, bool control_position = true) {
            Object (display: display, monitor_index: monitor_index, control_position: control_position);
        }

        static construct {
            gala_background_settings = new Settings (GALA_BACKGROUND_SCHEMA);
        }

        construct {
            background_source = BackgroundCache.get_default ().get_background_source (display, GNOME_BACKGROUND_SCHEMA);
            background_actor = create_background_actor ();

            destroy.connect (on_destroy);
        }

        private void on_destroy () {
            BackgroundCache.get_default ().release_background_source (GNOME_BACKGROUND_SCHEMA);
            background_source = null;

            if (new_background_actor != null) {
                new_background_actor.destroy ();
                new_background_actor = null;
            }

            if (background_actor != null) {
                background_actor.destroy ();
                background_actor = null;
            }
        }

        private void swap_background_actor (bool animate) {
            return_if_fail (new_background_actor != null);

            var old_background_actor = background_actor;
            background_actor = new_background_actor;
            new_background_actor = null;

            if (old_background_actor == null)
                return;

            if (animate) {
                var transition = new Clutter.PropertyTransition ("opacity");
                transition.set_from_value (255);
                transition.set_to_value (0);
                transition.duration = FADE_ANIMATION_TIME;
                transition.progress_mode = Clutter.AnimationMode.EASE_OUT_QUAD;
                transition.remove_on_complete = true;
                transition.completed.connect (() => {
                    old_background_actor.destroy ();

                    changed ();
                });

                old_background_actor.add_transition ("fade-out", transition);
            } else {
                old_background_actor.destroy ();
                changed ();
            }
        }

        private void update_background_actor (bool animate = true) {
            if (new_background_actor != null) {
                // Skip displaying existing background queued for load
                new_background_actor.destroy ();
                new_background_actor = null;
            }

            new_background_actor = create_background_actor ();
            var new_content = (Meta.BackgroundContent)new_background_actor.content;
            var old_content = (Meta.BackgroundContent)background_actor.content;
            new_content.vignette_sharpness = old_content.vignette_sharpness;
            new_content.brightness = old_content.brightness;
            new_background_actor.visible = background_actor.visible;


            var background = new_content.background.get_data<unowned Background> ("delegate");

            if (background.is_loaded) {
                swap_background_actor (animate);
                return;
            }

            ulong handler = 0;
            handler = background.loaded.connect (() => {
                SignalHandler.disconnect (background, handler);
                background.set_data<ulong> ("background-loaded-handler", 0);

                swap_background_actor (animate);
            });
            background.set_data<ulong> ("background-loaded-handler", handler);
        }

        public new void set_size (float width, float height) {
            if (width != background_actor.width || height != background_actor.height) {
                update_background_actor (false);
            }
        }

        private Meta.BackgroundActor create_background_actor () {
            var background = background_source.get_background (monitor_index);
            var background_actor = new Meta.BackgroundActor (display, monitor_index);

            ((Meta.BackgroundContent)background_actor.content).background = background.background;
            ((Meta.BackgroundContent)background_actor.content).vignette = true;

            // Don't play dim animation when launching gala or switching wallpaper
            if (should_dim ()) {
                ((Meta.BackgroundContent)background_actor.content).brightness = DIM_OPACITY;
            }

            Granite.Settings.get_default ().notify["prefers-color-scheme"].connect (update_dim_wallpaper);
            gala_background_settings.changed[DIM_WALLPAPER_KEY].connect (update_dim_wallpaper);

            insert_child_below (background_actor, null);

            var monitor = display.get_monitor_geometry (monitor_index);
            background_actor.set_size (monitor.width, monitor.height);

            if (control_position) {
                background_actor.set_position (monitor.x, monitor.y);
            }

            ulong changed_handler = 0;
            changed_handler = background.changed.connect (() => {
                SignalHandler.disconnect (background, changed_handler);
                changed_handler = 0;
                update_background_actor ();
            });

            background_actor.destroy.connect (() => {
                if (changed_handler != 0) {
                    SignalHandler.disconnect (background, changed_handler);
                    changed_handler = 0;
                }

                var loaded_handler = background.get_data<ulong> ("background-loaded-handler");
                if (loaded_handler != 0) {
                    SignalHandler.disconnect (background, loaded_handler);
                    background.set_data<ulong> ("background-loaded-handler", 0);
                }
            });

            return background_actor;
        }

        private bool should_dim () {
            return (
                Granite.Settings.get_default ().prefers_color_scheme == Granite.Settings.ColorScheme.DARK &&
                gala_background_settings.get_boolean (DIM_WALLPAPER_KEY)
            );
        }

        // OpacityDimActor is used for transitioning background actor's vignette brightness
        // In mutter 3.38+ vignette's properties are contained in Meta.BackgroundContent
        // which doesn't support transitions
        // so we bind OpacityDimActor.opacity to ((Meta.BackgroundContent) background_actor.content).brightness
        // and then create transition for OpacityDimActor.opacity

        private class OpacityDimActor : Clutter.Actor {
            public new double opacity { get; set; }
        }

        private void update_dim_wallpaper () {
            if (last_dim_transition != null) {
                last_dim_transition.stop ();
            }

            var dim_actor = new OpacityDimActor ();
            background_actor.add_child (dim_actor);
            var binding = dim_actor.bind_property (
                "opacity",
                (Meta.BackgroundContent) background_actor.content,
                "brightness",
                BindingFlags.DEFAULT
            );

            var transition = new Clutter.PropertyTransition ("opacity");
            transition.set_from_value (
                ((Meta.BackgroundContent) background_actor.content).brightness
            );
            transition.set_to_value (should_dim () ? DIM_OPACITY : 1.0);
            transition.duration = FADE_ANIMATION_TIME;
            transition.progress_mode = Clutter.AnimationMode.EASE_OUT_QUAD;
            transition.remove_on_complete = true;
            transition.completed.connect (() => {
                binding.unbind ();

                background_actor.remove_child (dim_actor);
                dim_actor.destroy ();

                changed ();
            });

            dim_actor.add_transition ("wallpaper-dim", transition);

            last_dim_transition = transition;
        }
    }
}
