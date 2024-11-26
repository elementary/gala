/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 *                         2012-2014 Tom Beckmann
 *                         2012-2014 Jacob Parker
 */

[DBus (name="org.pantheon.gala")]
public class Gala.DBus {
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
                    connection.register_object ("/org/gnome/Shell", DBusAccelerator.init (wm.get_display ()));
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
