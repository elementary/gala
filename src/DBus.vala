/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024-2025 elementary, Inc. (https://elementary.io)
 *                         2012-2014 Tom Beckmann
 *                         2012-2014 Jacob Parker
 */

[DBus (name="io.elementary.gala")]
public class Gala.DBus {
    private static DBus? instance;
    private static WindowManagerGala wm;

    [DBus (visible = false)]
    public static void init (WindowManagerGala _wm, NotificationsManager notifications_manager, ScreenshotManager screenshot_manager) {
        wm = _wm;

        Bus.own_name (BusType.SESSION, "io.elementary.gala", BusNameOwnerFlags.NONE,
            (connection) => {
                if (instance == null)
                    instance = new DBus ();

                try {
                    connection.register_object ("/io/elementary/gala", instance);
                } catch (Error e) { warning (e.message); }

                try {
                    connection.register_object ("/io/elementary/gala/DesktopInterface", new DesktopIntegration (wm));
                } catch (Error e) { warning (e.message); }
            },
            () => {},
            () => warning ("Could not acquire name") );

        Bus.own_name (BusType.SESSION, "org.gnome.Shell", BusNameOwnerFlags.NONE,
            (connection) => {
                try {
                    connection.register_object ("/org/gnome/Shell", new DBusAccelerator (wm.get_display (), notifications_manager));
                    connection.register_object ("/org/gnome/Shell/Screenshot", screenshot_manager);
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
