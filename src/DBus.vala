/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024-2025 elementary, Inc. (https://elementary.io)
 *                         2012-2014 Tom Beckmann
 *                         2012-2014 Jacob Parker
 */

[DBus (name="org.pantheon.gala")]
public class Gala.DBus {
    private static DBus? instance;
    private static WindowManagerGala wm;

    [DBus (visible = false)]
    public static void init (WindowManagerGala _wm, NotificationsManager notifications_manager, ScreenshotManager screenshot_manager) {
        wm = _wm;

        try {
            var session_connection = Bus.get_sync (SESSION, null);

            Bus.own_name_on_connection (session_connection, "io.elementary.gala", NONE,
                (connection, name) => {
                    try {
                        connection.register_object ("/io/elementary/gala", WindowDragProvider.get_instance ());
                    } catch (Error e) {
                        warning (e.message);
                    }
                },
                print_warning
            );

            Bus.own_name_on_connection (session_connection, "org.pantheon.gala", NONE,
                (connection, name) => {
                    if (instance == null) {
                        instance = new DBus ();
                    }

                    try {
                        connection.register_object ("/org/pantheon/gala", instance);
                        connection.register_object ("/org/pantheon/gala/DesktopInterface", new DesktopIntegration (wm));
                    } catch (Error e) {
                        warning (e.message);
                    }
                },
                print_warning
            );

            Bus.own_name_on_connection (session_connection, "org.gnome.Shell", NONE,
                (connection, name) => {
                    try {
                        connection.register_object ("/org/gnome/Shell", new DBusAccelerator (wm.get_display (), notifications_manager));
                        connection.register_object ("/org/gnome/Shell/Screenshot", screenshot_manager);
                    } catch (Error e) {
                        warning (e.message);
                    }
                },
                print_warning
            );

            Bus.own_name_on_connection (session_connection, "org.gnome.Shell.Screenshot", REPLACE,
                null,
                print_warning
            );

            Bus.own_name_on_connection (session_connection, "org.gnome.SessionManager.EndSessionDialog", NONE,
                (connection, name) => {
                    try {
                        connection.register_object ("/org/gnome/SessionManager/EndSessionDialog", SessionManager.init ());
                    } catch (Error e) {
                        warning (e.message);
                    }
                },
                print_warning
            );

            Bus.own_name_on_connection (session_connection, "org.gnome.ScreenSaver", REPLACE,
                (connection, name) => {
                    try {
                        connection.register_object ("/org/gnome/ScreenSaver", wm.screensaver);
                    } catch (Error e) {
                        warning (e.message);
                    }
                },
                print_warning
            );
        } catch (Error e) {
            critical ("Couldn't connect to DBus");
        }
    }

    private static void print_warning (GLib.DBusConnection connection, string name) {
        warning ("DBus: Lost name %s", name);
    }

    public void perform_action (ActionType type) throws DBusError, IOError {
        wm.perform_action (type);
    }
}
