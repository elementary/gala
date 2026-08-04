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
#if HAS_MUTTER50
    public static void init (WindowManagerGala _wm, NotificationsManager notifications_manager, ScreenshotManager screenshot_manager, BrightnessManager brightness_manager) {
#else
    public static void init (WindowManagerGala _wm, NotificationsManager notifications_manager, ScreenshotManager screenshot_manager) {
#endif
        wm = _wm;

        Bus.own_name (
            SESSION, "io.elementary.gala", NONE, null,
            (connection, name) => {
                try {
                    connection.register_object ("/io/elementary/gala", WindowDragProvider.get_instance ());
#if HAS_MUTTER50
                    connection.register_object ("/io/elementary/gala/BrightnessManager", brightness_manager);
                    brightness_manager.monitor_added.connect ((monitor_brightness) => {
                        try {
                            var id = connection.register_object (@"/io/elementary/gala/BrightnessManager/$(monitor_brightness.get_monitor_serial ())", monitor_brightness);
                            return id;
                        } catch (Error e) {
                            warning (e.message);
                            return null;
                        }
                    });
                    brightness_manager.monitor_removed.connect ((connection_id) => {
                        connection.unregister_object (connection_id);
                    });
                    brightness_manager.update_available_backlights ();
#endif
                } catch (Error e) {
                    warning (e.message);
                }
            },
            on_name_lost
        );

        Bus.own_name (
            SESSION, "org.pantheon.gala", NONE, null,
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
            on_name_lost
        );

        Bus.own_name (
            SESSION, "org.gnome.Shell", NONE, null,
            (connection, name) => {
                try {
                    connection.register_object ("/org/gnome/Shell", new DBusAccelerator (wm.get_display (), notifications_manager));
                    connection.register_object ("/org/gnome/Shell/Screenshot", screenshot_manager);
                } catch (Error e) {
                    warning (e.message);
                }
            },
            on_name_lost
        );

        Bus.own_name (
            SESSION, "org.gnome.Shell.Screenshot", REPLACE, null,
            null,
            on_name_lost
        );

        Bus.own_name (
            SESSION, "org.gnome.SessionManager.EndSessionDialog", NONE, null,
            (connection, name) => {
                try {
                    connection.register_object ("/org/gnome/SessionManager/EndSessionDialog", SessionManager.init ());
                } catch (Error e) {
                    warning (e.message);
                }
            },
            on_name_lost
        );

        Bus.own_name (
            SESSION, "org.gnome.ScreenSaver", REPLACE, null,
            (connection, name) => {
                try {
                    connection.register_object ("/org/gnome/ScreenSaver", wm.screensaver);
                } catch (Error e) {
                    warning (e.message);
                }
            },
            on_name_lost
        );
    }

    private static void on_name_lost (GLib.DBusConnection connection, string name) {
        warning ("DBus: Lost name %s", name);
    }

    public void perform_action (ActionType type) throws DBusError, IOError {
        wm.perform_action (type);
    }
}
