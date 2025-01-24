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

        public abstract uint32 notify (string app_name, uint32 replaces_id, string app_icon, string summary,
            string body, string[] actions, HashTable<string, Variant> hints, int32 expire_timeout) throws DBusError, IOError;
    }

    private const int EXPIRE_TIMEOUT = 2000;

    /**
     * Data structure to hold notification data. Component name is used to correctly replace notifications.
     */
    [Compact]
    public class NotificationData {
        public string component_name;
        public string icon;
        public string summary;
        public string body;
        public string[] actions;
        public GLib.HashTable<string, Variant> hints;

        public NotificationData (
            string _component_name,
            string _icon,
            string _summary,
            string _body,
            string[] _actions,
            GLib.HashTable<string, Variant> _hints
        ) {
            component_name = _component_name;
            icon = _icon;
            summary = _summary;
            body = _body;
            actions = _actions;
            hints = _hints;
        }
    }

    private GLib.SimpleActionGroup action_group = new GLib.SimpleActionGroup ();
    private ThreadPool<NotificationData>? pool = null;
    private DBusNotifications? notifications = null;
    private GLib.HashTable<string, uint32> replaces_id_table = new GLib.HashTable<string, uint32> (str_hash, str_equal);

    construct {
        try {
            pool = new ThreadPool<NotificationData>.with_owned_data (send_feedback, 1, false);
        } catch (ThreadError e) {
            warning (e.message);
            pool = null;
        }

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
                    notifications.action_invoked.connect (handle_action_invoked);
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

    public void send (owned NotificationData notification_data) {
        if (pool == null) {
            return;
        }

        try {
            pool.add ((owned) notification_data);
        } catch (ThreadError e) {
            warning ("NotificationsManager: could't add notificationData: %s", e.message);
        }
    }

    public void add_action (GLib.Action action) {
        action_group.add_action (action);
    }

    private void send_feedback (owned NotificationData notification_data) {
        if (notifications == null) {
            return;
        }

        uint32? replaces_id = replaces_id_table.get (notification_data.component_name);
        if (replaces_id == null) {
            replaces_id = 0;
        }

        try {
            var notification_id = notifications.notify (
                "gala-feedback",
                replaces_id,
                notification_data.icon,
                notification_data.summary,
                notification_data.body,
                notification_data.actions,
                notification_data.hints,
                EXPIRE_TIMEOUT
            );

            replaces_id_table.insert (notification_data.component_name, notification_id);
        } catch (Error e) {
            critical (e.message);
        }
    }

    private void handle_action_invoked (uint32 id, string action_name) {
        string name;
        GLib.Variant? target_value;

        try {
            GLib.Action.parse_detailed_name (action_name, out name, out target_value);
        } catch (Error e) {
            warning (e.message);
            return;
        }

        if (action_group.has_action (name)) {
            action_group.activate_action (name, target_value);
        }
    }
}
