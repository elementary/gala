/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2016 Rico Tzschichholz
 *                         2025 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "org.freedesktop.Notifications")]
interface Gala.DBusNotifications : GLib.Object {
    public abstract uint32 notify (string app_name, uint32 replaces_id, string app_icon, string summary,
        string body, string[] actions, HashTable<string, Variant> hints, int32 expire_timeout) throws DBusError, IOError;
}

public class Gala.MediaFeedback : GLib.Object {
    [Compact]
    class Feedback {
        public string icon;
        public int32 level;

        public Feedback (string _icon, int32 _level) {
            icon = _icon;
            level = _level;
        }
    }

    private ThreadPool<Feedback>? pool = null;

    private DBusNotifications? notifications = null;
    private uint32 notification_id = 0;

    construct {
        try {
            pool = new ThreadPool<Feedback>.with_owned_data (send_feedback, 1, false);
        } catch (ThreadError e) {
            critical ("%s", e.message);
            pool = null;
        }

        try {
            Bus.watch_name (BusType.SESSION, "org.freedesktop.Notifications", BusNameWatcherFlags.NONE, on_watch, on_unwatch);
        } catch (IOError e) {
            debug (e.message);
        }
    }

    private void on_watch (DBusConnection conn) {
        conn.get_proxy.begin<DBusNotifications> ("org.freedesktop.Notifications",
            "/org/freedesktop/Notifications", DBusProxyFlags.NONE, null, (obj, res) => {
            try {
                notifications = ((DBusConnection) obj).get_proxy.end<DBusNotifications> (res);
            } catch (Error e) {
                debug (e.message);
                notifications = null;
            }
        });
    }

    private void on_unwatch (DBusConnection conn) {
        notifications = null;
    }

    public void send (string icon, int val) requires (pool != null) {
        try {
            pool.add (new Feedback (icon, val));
        } catch (ThreadError e) {
            warning ("MediaFeedback: could't add feedback: %s", e.message);
        }
    }

    private void send_feedback (owned Feedback feedback) {
        if (notifications == null) {
            return;
        }

        var hints = new GLib.HashTable<string, Variant> (null, null);
        hints.set ("x-canonical-private-synchronous", new Variant.string ("gala-feedback"));
        hints.set ("value", new Variant.int32 (feedback.level));

        try {
            notification_id = notifications.notify ("gala-feedback", notification_id, feedback.icon, "", "", {}, hints, 2000);
        } catch (Error e) {
            critical ("%s", e.message);
        }
    }
}
