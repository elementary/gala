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
        public signal void action_invoked (uint32 id, string action_key);
        public signal void notification_closed (uint32 id, uint32 reason);

        public abstract async uint32 notify (string app_name, uint32 replaces_id, string app_icon, string summary,
            string body, string[] actions, HashTable<string, Variant> hints, int32 expire_timeout) throws DBusError, IOError;
    }

    private const int EXPIRE_TIMEOUT = 2000;

    public signal void action_invoked (uint32 id, string name, GLib.Variant? target_value);

    private DBusNotifications? notifications = null;
    private GLib.HashTable<string, uint32> replaces_id_table = new GLib.HashTable<string, uint32> (str_hash, str_equal);

    construct {
        Bus.watch_name (BusType.SESSION, "org.freedesktop.Notifications", BusNameWatcherFlags.NONE, on_watch, on_unwatch);
    }

    private void on_watch (DBusConnection connection) {
        connection.get_proxy.begin<DBusNotifications> (
            "org.freedesktop.Notifications", "/org/freedesktop/Notifications", DBusProxyFlags.NONE, null,
            (obj, res) => {
                try {
                    notifications = ((DBusConnection) obj).get_proxy.end<DBusNotifications> (res);
                    notifications.action_invoked.connect (handle_action_invoked);
                } catch (Error e) {
                    warning ("NotificationsManager: Couldn't connect to notifications server: %s", e.message);
                    notifications = null;
                }
            }
        );
    }

    private void on_unwatch (DBusConnection conn) {
        warning ("NotificationsManager: Lost connection to notifications server");
        notifications = null;
    }

    private void handle_action_invoked (uint32 id, string action_name) {
        string name;
        GLib.Variant? target_value;

        try {
            GLib.Action.parse_detailed_name (action_name, out name, out target_value);
        } catch (Error e) {
            warning ("NotificationsManager: Couldn't parse action: %s", e.message);
            return;
        }

        action_invoked (id, name, target_value);
    }

    public async uint32? send (
        string component_name,
        string icon,
        string summary,
        string body,
        string[] actions,
        GLib.HashTable<string, Variant> hints
    ) {
        if (notifications == null) {
            warning ("NotificationsManager: Unable to send notification. No connection to notification server");
            return null;
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
                actions,
                hints,
                EXPIRE_TIMEOUT
            );

            replaces_id_table.insert (component_name, notification_id);

            return notification_id;
        } catch (Error e) {
            critical ("NotificationsManager: There was an error sending a notification: %s", e.message);
            return null;
        }
    }
}
