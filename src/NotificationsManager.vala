/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2016 Rico Tzschichholz
 *                         2025 elementary, Inc. (https://elementary.io)
 */

/**
 * Gala.NotificationsManager can be used to send notifications to org.freedesktop.Notifications
 */
public class Gala.NotificationsManager : GLib.Object {
    [DBus (name = "org.freedesktop.Notifications")]
    private interface DBusNotifications : GLib.Object {
        public abstract async uint32 notify (string app_name, uint32 replaces_id, string app_icon, string summary,
            string body, string[] actions, HashTable<string, Variant> hints, int32 expire_timeout) throws DBusError, IOError;
    }

    private const int EXPIRE_TIMEOUT = 2000;

    private DBusNotifications? notifications = null;
    private GLib.HashTable<string, uint32> replaces_id_table = new GLib.HashTable<string, uint32> (str_hash, str_equal);

    construct {
        try {
            Bus.watch_name (BusType.SESSION, "org.freedesktop.Notifications", BusNameWatcherFlags.NONE, on_watch, on_unwatch);
        } catch (IOError e) {
            warning (e.message);
        }
    }

    private void on_watch (DBusConnection conn) {
        conn.get_proxy.begin<DBusNotifications> (
            "org.freedesktop.Notifications", "/org/freedesktop/Notifications", DBusProxyFlags.NONE, null,
            (obj, res) => {
                try {
                    notifications = ((DBusConnection) obj).get_proxy.end<DBusNotifications> (res);
                } catch (Error e) {
                    warning (e.message);
                    notifications = null;
                }
            }
        );
    }

    private void on_unwatch (DBusConnection conn) {
        notifications = null;
    }

    public async void send (string component_name, string summary, string body, string icon, HashTable<string, Variant> hints) {
        if (notifications == null) {
            return;
        }

        uint32? replaces_id = replaces_id_table.get (component_name);
        if (replaces_id == null) {
            replaces_id = 0;
        }

        try {
            var notification_id = yield notifications.notify (
                "gala-feedback",
                replaces_id,
                icon,
                summary,
                body,
                {},
                hints,
                EXPIRE_TIMEOUT
            );

            replaces_id_table.insert (component_name, notification_id);
        } catch (Error e) {
            critical (e.message);
        }
    }
}
