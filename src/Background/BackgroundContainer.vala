//
//  Copyright (C) 2013 Tom Beckmann, Rico Tzschichholz
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
    public class BackgroundContainer : Meta.BackgroundGroup {
        public signal void changed ();

#if HAS_MUTTER330
        public Meta.Display display { get; construct; }

        public BackgroundContainer (Meta.Display display) {
            Object (display: display);
        }

        construct {
            Meta.MonitorManager.@get ().monitors_changed.connect (update);

            Bus.watch_name (BusType.SESSION, DAEMON_DBUS_NAME, BusNameWatcherFlags.NONE, daemon_appeared, lost_daemon);

            update ();
        }

        ~BackgroundContainer () {
            Meta.MonitorManager.@get ().monitors_changed.disconnect (update);
        }
#else
        public Meta.Screen screen { get; construct; }

        public BackgroundContainer (Meta.Screen screen) {
            Object (screen: screen);
        }

        construct {
            screen.monitors_changed.connect (update);

            update ();
        }

        ~BackgroundContainer () {
            screen.monitors_changed.disconnect (update);
        }
#endif

        void on_menu_get (GLib.Object? o, GLib.AsyncResult? res) {
            try {
                WindowManagerGala.get_default ().daemon_proxy = Bus.get_proxy.end (res);
            } catch (Error e) {
                warning ("Failed to get Menu proxy: %s", e.message);
            }
        }

        void lost_daemon () {
            WindowManagerGala.get_default ().daemon_proxy = null;
        }

        void daemon_appeared () {
            if (WindowManagerGala.get_default ().daemon_proxy == null) {
                Bus.get_proxy.begin<Daemon> (BusType.SESSION, DAEMON_DBUS_NAME, DAEMON_DBUS_OBJECT_PATH, 0, null, on_menu_get);
            }
        }

        void update () {
            var reference_child = (get_child_at_index (0) as BackgroundManager);
            if (reference_child != null)
                reference_child.changed.disconnect (background_changed);

            destroy_all_children ();

#if HAS_MUTTER330
            for (var i = 0; i < display.get_n_monitors (); i++) {
                var background = new BackgroundManager (display, i);
#else
            for (var i = 0; i < screen.get_n_monitors (); i++) {
                var background = new BackgroundManager (screen, i);
#endif

                add_child (background);

                if (i == 0)
                    background.changed.connect (background_changed);
            }
        }

        void background_changed () {
            changed ();
        }
    }
}
