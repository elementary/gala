//
//  Copyright 2018-2020 elementary, Inc. (https://elementary.io)
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
    public struct MonitorLabelInfo {
        public int monitor;
        public string label;
        public string background_color;
        public string text_color;
        public int x;
        public int y;
    }

    private const string DBUS_NAME = "org.pantheon.gala";
    private const string DBUS_OBJECT_PATH = "/org/pantheon/gala";

    private const string DAEMON_DBUS_NAME = "org.pantheon.gala.daemon";
    private const string DAEMON_DBUS_OBJECT_PATH = "/org/pantheon/gala/daemon";

    [DBus (name = "org.pantheon.gala")]
    public interface WMDBus : GLib.Object {
        public abstract void perform_action (Gala.ActionType type) throws DBusError, IOError;
    }

    [DBus (name = "org.pantheon.gala.daemon")]
    public class MenuDaemon : Object {
        private WMDBus? wm_proxy = null;

        private WindowMenu? window_menu;

        private ulong always_on_top_sid = 0U;
        private ulong on_visible_workspace_sid = 0U;

        construct {
            Bus.watch_name (BusType.SESSION, DBUS_NAME, BusNameWatcherFlags.NONE, gala_appeared, lost_gala);
        }

        private void on_gala_get (GLib.Object? o, GLib.AsyncResult? res) {
            try {
                wm_proxy = Bus.get_proxy.end (res);
            } catch (Error e) {
                warning ("Failed to get Gala proxy: %s", e.message);
            }
        }

        private void lost_gala () {
            wm_proxy = null;
        }

        private void gala_appeared () {
            if (wm_proxy == null) {
                Bus.get_proxy.begin<WMDBus> (BusType.SESSION, DBUS_NAME, DBUS_OBJECT_PATH, 0, null, on_gala_get);
            }
        }

        private void perform_action (Gala.ActionType type) {
            if (wm_proxy != null) {
                try {
                    wm_proxy.perform_action (type);
                } catch (Error e) {
                    warning ("Failed to perform Gala action over DBus: %s", e.message);
                }
            }
        }

        private void init_window_menu () {
        }

        public void show_window_menu (Gala.WindowFlags flags, int display_width, int display_height, int x, int y) throws DBusError, IOError {
            if (window_menu == null) {
                window_menu = new WindowMenu ();
            }

            window_menu.update (flags);

            var window = new Window (display_width, display_height);
            window.present ();

            window_menu.set_relative_to (window.content);

            Gdk.Rectangle rect = {
                x,
                y,
                display_width,
                display_height
            };

            window_menu.pointing_to = rect;

            window_menu.popup ();
            window_menu.show_all ();

            warning ("SHOW");
        }

        public void show_desktop_menu (int x, int y) throws DBusError, IOError {
        }

        public void show_monitor_labels (MonitorLabelInfo[] label_infos) throws GLib.DBusError, GLib.IOError {
        }

        public void hide_monitor_labels () throws GLib.DBusError, GLib.IOError {
        }
    }
}
