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
    public class BackgroundSource : Object {
        // list of keys that are actually relevant for us
        private const string[] OPTIONS = {
            "color-shading-type",
            "picture-options",
            "picture-uri",
            "picture-uri-dark",
            "primary-color",
            "secondary-color"
        };

        public signal void changed ();

        public Meta.Display display { get; construct; }
        public GLib.Settings gnome_background_settings { get; private set; }

        internal int use_count { get; set; default = 0; }

        private GLib.HashTable<int, Background> backgrounds;
        private uint[] hash_cache;
        private Meta.MonitorManager? monitor_manager;
        private GLib.Settings gala_background_settings;

        public bool should_dim {
            get {
                return (
                    Drawing.StyleManager.get_instance ().prefers_color_scheme == DARK &&
                    gala_background_settings.get_boolean ("dim-wallpaper-in-dark-style")
                );
            }
        }

        public BackgroundSource (Meta.Display display) {
            Object (display: display);
        }

        construct {
            backgrounds = new GLib.HashTable<int, Background> (GLib.direct_hash, GLib.direct_equal);
            hash_cache = new uint[OPTIONS.length];

            monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
            monitor_manager.monitors_changed.connect (monitors_changed);

            gala_background_settings = new GLib.Settings ("io.elementary.desktop.background");
            gala_background_settings.changed["dim-wallpaper-in-dark-style"].connect (() => changed ());

            Drawing.StyleManager.get_instance ().notify["prefers-color-scheme"].connect (() => changed ());

            gnome_background_settings = new GLib.Settings ("org.gnome.desktop.background");

            // unfortunately the settings sometimes tend to fire random changes even though
            // nothing actually happened. The code below is used to prevent us from spamming
            // new actors all the time, which lead to some problems in other areas of the code
            for (int i = 0; i < OPTIONS.length; i++) {
                hash_cache[i] = gnome_background_settings.get_value (OPTIONS[i]).hash ();
            }

            gnome_background_settings.changed.connect ((key) => {
                for (int i = 0; i < OPTIONS.length; i++) {
                    if (key == OPTIONS[i]) {
                        uint new_hash = gnome_background_settings.get_value (key).hash ();
                        if (hash_cache[i] != new_hash) {
                            hash_cache[i] = new_hash;
                            changed ();
                            break;
                        }
                    }
                }
            });
        }

        private void monitors_changed () {
            var n = display.get_n_monitors ();
            var i = 0;

            backgrounds.foreach_remove ((hash, background) => {
                if (i++ < n) {
                    background.update_resolution ();
                    return false;
                } else {
                    background.changed.disconnect (background_changed);
                    background.destroy ();
                    return true;
                }
            });
        }

        public Background get_background (int monitor_index) {
            string? filename = null;

            var style = gnome_background_settings.get_enum ("picture-options");
            if (style != GDesktop.BackgroundStyle.NONE) {
                filename = get_background_path ();
            }

            // Animated backgrounds are (potentially) per-monitor, since
            // they can have variants that depend on the aspect ratio and
            // size of the monitor; for other backgrounds we can use the
            // same background object for all monitors.
            if (filename == null || !filename.has_suffix (".xml"))
                monitor_index = 0;

            var background = backgrounds.lookup (monitor_index);
            if (background == null) {
                background = new Background (display, monitor_index, filename, this, (GDesktop.BackgroundStyle) style);
                background.changed.connect (background_changed);
                backgrounds.insert (monitor_index, background);
            }

            return background;
        }

        private string get_background_path () {
            if (Drawing.StyleManager.get_instance ().prefers_color_scheme == DARK) {
                var uri = gnome_background_settings.get_string ("picture-uri-dark");
                var path = File.new_for_uri (uri).get_path ();
                if (FileUtils.test (path, EXISTS)) {
                    return path;
                }
            }

            var uri = gnome_background_settings.get_string ("picture-uri");
            var path = File.new_for_uri (uri).get_path ();
            if (FileUtils.test (path, EXISTS)) {
                return path;
            }

            return uri;
        }

        private void background_changed (Background background) {
            background.changed.disconnect (background_changed);
            background.destroy ();
            backgrounds.remove (background.monitor_index);
        }

        public void destroy () {
            monitor_manager.monitors_changed.disconnect (monitors_changed);
            monitor_manager = null;

            backgrounds.foreach_remove ((hash, background) => {
                background.changed.disconnect (background_changed);
                background.destroy ();
                return true;
            });
        }
    }
}
