/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024-2025 elementary, Inc. (https://elementary.io)
 *                         2012-2014 Tom Beckmann
 *                         2012-2014 Jacob Parker
 */

[DBus (name="org.pantheon.gala")]
public class Gala.DBus {
    private WindowManagerGala wm;

    [DBus (visible = false)]
    public DBus (WindowManagerGala _wm) {
        wm = _wm;
    }

    public void perform_action (ActionType type) throws DBusError, IOError {
        wm.perform_action (type);
    }
}


public class Gala.DBusManager : GLib.Object {
    public DBusManager (WindowManagerGala wm, DBusAccelerator dbus_accelerator, ScreenshotManager screenshot_manager) {
        Bus.own_name (BusType.SESSION, "org.pantheon.gala", BusNameOwnerFlags.NONE,
            (connection) => {
                try {
                    connection.register_object ("/org/pantheon/gala", new DBus (wm));
                } catch (Error e) {
                    warning (e.message);
                }

                try {
                    connection.register_object ("/org/pantheon/gala/DesktopInterface", new DesktopIntegration (wm));
                } catch (Error e) {
                    warning (e.message);
                }
            },
            () => {},
            () => warning ("Could not acquire name")
        );

        Bus.own_name (BusType.SESSION, "org.gnome.Shell", BusNameOwnerFlags.NONE,
            (connection) => {
                try {
                    connection.register_object ("/org/gnome/Shell", dbus_accelerator);
                    connection.register_object ("/org/gnome/Shell/Screenshot", screenshot_manager);
                } catch (Error e) { warning (e.message); }
            },
            () => {},
            () => critical ("Could not acquire name")
        );

        Bus.own_name (BusType.SESSION, "org.gnome.Shell.Screenshot", BusNameOwnerFlags.REPLACE,
            () => {},
            () => {},
            () => critical ("Could not acquire name")
        );

        Bus.own_name (BusType.SESSION, "org.gnome.SessionManager.EndSessionDialog", BusNameOwnerFlags.NONE,
            (connection) => {
                try {
                    connection.register_object ("/org/gnome/SessionManager/EndSessionDialog", SessionManager.init ());
                } catch (Error e) {
                    warning (e.message);
                }
            },
            () => {},
            () => critical ("Could not acquire name")
        );

        Bus.own_name (BusType.SESSION, "org.gnome.ScreenSaver", BusNameOwnerFlags.REPLACE,
            (connection) => {
                try {
                    connection.register_object ("/org/gnome/ScreenSaver", wm.screensaver);
                } catch (Error e) {
                    warning (e.message);
                }
            },
            () => {},
            () => critical ("Could not acquire ScreenSaver bus")
        );
    }
}
