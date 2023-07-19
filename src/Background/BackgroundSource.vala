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
        public signal void changed ();

        public Meta.Display display { get; construct; }
        public GLib.Settings gnome_background_settings;

        internal int use_count { get; set; default = 0; }

        private Gee.HashMap<int,Background> backgrounds;
        private GLib.Settings gala_background_settings;

        public BackgroundSource (Meta.Display display) {
            Object (display: display);
        }

        construct {
            backgrounds = new Gee.HashMap<int,Background> ();

            unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
            monitor_manager.monitors_changed.connect (monitors_changed);

            gnome_background_settings = new GLib.Settings ("org.gnome.desktop.background");
            gnome_background_settings.changed["color-shading-type"].connect (() => changed ());
            gnome_background_settings.changed["picture-options"].connect (() => changed ());
            gnome_background_settings.changed["picture-uri"].connect (() => changed ());
            gnome_background_settings.changed["picture-uri-dark"].connect (() => changed ());
            gnome_background_settings.changed["primary-color"].connect (() => changed ());
            gnome_background_settings.changed["secondary-color"].connect (() => changed ());

            gala_background_settings = new Settings ("io.elementary.desktop.background");
            gala_background_settings.changed["dim-wallpaper-in-dark-style"].connect (() => changed ());

            unowned var granite_settings = Granite.Settings.get_default ();
            granite_settings.notify["prefers-color-scheme"].connect (() => changed ());
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

            if (!backgrounds.has_key (monitor_index)) {
                var background = new Background (display, monitor_index, filename, this, (GDesktop.BackgroundStyle) style);
                background.changed.connect (background_changed);
                backgrounds[monitor_index] = background;
            }

            return backgrounds[monitor_index];
        }

        private string get_background_path () {
            if (Granite.Settings.get_default ().prefers_color_scheme == DARK) {
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

        public bool should_dim () {
            return (
                Granite.Settings.get_default ().prefers_color_scheme == Granite.Settings.ColorScheme.DARK &&
                gala_background_settings.get_boolean ("dim-wallpaper-in-dark-style")
            );
        }
    }
}
