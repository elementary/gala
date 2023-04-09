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
            "picture-opacity",
            "picture-options",
            "picture-uri",
            "primary-color",
            "secondary-color"
        };

        public signal void changed ();

        public Meta.Display display { get; construct; }
        public Settings settings { get; construct; }

        internal int use_count { get; set; default = 0; }

        private Gee.HashMap<int,Background> backgrounds;
        private uint[] hash_cache;

        public BackgroundSource (Meta.Display display, string settings_schema) {
            Object (display: display, settings: new Settings (settings_schema));
        }

        construct {
            backgrounds = new Gee.HashMap<int,Background> ();
            hash_cache = new uint[OPTIONS.length];

            unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
            monitor_manager.monitors_changed.connect (monitors_changed);

            // unfortunately the settings sometimes tend to fire random changes even though
            // nothing actually happened. The code below is used to prevent us from spamming
            // new actors all the time, which lead to some problems in other areas of the code
            for (int i = 0; i < OPTIONS.length; i++) {
                hash_cache[i] = settings.get_value (OPTIONS[i]).hash ();
            }

            settings.changed.connect ((key) => {
                for (int i = 0; i < OPTIONS.length; i++) {
                    if (key == OPTIONS[i]) {
                        uint new_hash = settings.get_value (key).hash ();
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

            foreach (var background in backgrounds.values) {
                if (i++ < n) {
                    background.update_resolution ();
                    continue;
                }

                background.changed.disconnect (background_changed);
                background.destroy ();
                // TODO can we remove from a list while iterating?
                backgrounds.unset (i);
            }
        }

        public Background get_background (int monitor_index) {
            string? filename = null;

            var style = settings.get_enum ("picture-options");
            if (style != GDesktop.BackgroundStyle.NONE) {
                var uri = settings.get_string ("picture-uri");
                if (Uri.parse_scheme (uri) != null)
                    filename = File.new_for_uri (uri).get_path ();
                else
                    filename = uri;
            }

            // Animated backgrounds are (potentially) per-monitor, since
            // they can have variants that depend on the aspect ratio and
            // size of the monitor; for other backgrounds we can use the
            // same background object for all monitors.
            if (filename == null || !filename.has_suffix (".xml"))
                monitor_index = 0;

            if (!backgrounds.has_key (monitor_index)) {
                var background = new Background (display, monitor_index, filename, this, (GDesktop.BackgroundStyle) style);
                background.changed.connect (background_changed);
                backgrounds[monitor_index] = background;
            }

            return backgrounds[monitor_index];
        }

        private void background_changed (Background background) {
            background.changed.disconnect (background_changed);
            background.destroy ();
            backgrounds.unset (background.monitor_index);
        }

        public void destroy () {
            unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
            monitor_manager.monitors_changed.disconnect (monitors_changed);

            foreach (var background in backgrounds.values) {
                background.changed.disconnect (background_changed);
                background.destroy ();
            }
        }
    }
}
