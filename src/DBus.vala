//
//  Copyright (C) 2012 - 2014 Tom Beckmann, Jacob Parker
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
    [DBus (name="org.pantheon.gala")]
    public class DBus {
        private static DBus? instance;
        private static WindowManagerGala wm;

        [DBus (visible = false)]
        public static void init (WindowManagerGala _wm) {
            wm = _wm;

            Bus.own_name (BusType.SESSION, "org.pantheon.gala", BusNameOwnerFlags.NONE,
                (connection) => {
                    if (instance == null)
                        instance = new DBus ();

                    try {
                        connection.register_object ("/org/pantheon/gala", instance);
                    } catch (Error e) { warning (e.message); }

                    try {
                        connection.register_object ("/org/pantheon/gala/DesktopInterface", new DesktopIntegration (wm));
                    } catch (Error e) { warning (e.message); }
                },
                () => {},
                () => warning ("Could not acquire name\n") );

            Bus.own_name (BusType.SESSION, "org.gnome.Shell", BusNameOwnerFlags.NONE,
                (connection) => {
                    try {
                        connection.register_object ("/org/gnome/Shell", DBusAccelerator.init (wm));
                        connection.register_object ("/org/gnome/Shell/Screenshot", ScreenshotManager.init (wm));
                    } catch (Error e) { warning (e.message); }
                },
                () => {},
                () => critical ("Could not acquire name") );

            Bus.own_name (BusType.SESSION, "org.gnome.Shell.Screenshot", BusNameOwnerFlags.REPLACE,
                () => {},
                () => {},
                () => critical ("Could not acquire name") );

            Bus.own_name (BusType.SESSION, "org.gnome.SessionManager.EndSessionDialog", BusNameOwnerFlags.NONE,
                (connection) => {
                    try {
                        connection.register_object ("/org/gnome/SessionManager/EndSessionDialog", SessionManager.init ());
                    } catch (Error e) { warning (e.message); }
                },
                () => {},
                () => critical ("Could not acquire name") );

            Bus.own_name (BusType.SESSION, "org.gnome.ScreenSaver", BusNameOwnerFlags.REPLACE,
                (connection) => {
                    try {
                        connection.register_object ("/org/gnome/ScreenSaver", wm.screensaver);
                    } catch (Error e) { warning (e.message); }
                },
                () => {},
                () => critical ("Could not acquire ScreenSaver bus") );
        }

        public void perform_action (ActionType type) throws DBusError, IOError {
            wm.perform_action (type);
        }
    }
}
