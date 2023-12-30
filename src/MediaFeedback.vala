//
//  Copyright (C) 2016 Rico Tzschichholz
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
    [DBus (name = "io.elementary.wingpanel.sound")]
    public interface WingpanelSound : GLib.Object {
        public abstract void handle_osd () throws DBusError, IOError;
    }

    [DBus (name = "org.freedesktop.Notifications")]
    public interface DBusNotifications : GLib.Object {
        public abstract uint32 notify (string app_name, uint32 replaces_id, string app_icon, string summary,
            string body, string[] actions, HashTable<string, Variant> hints, int32 expire_timeout) throws DBusError, IOError;
    }

    public class MediaFeedback : GLib.Object {
        [Compact]
        class Feedback {
            public string icon;
            public int32 level;

            public Feedback (string _icon, int32 _level) {
                icon = _icon;
                level = _level;
            }
        }

        private static MediaFeedback? instance = null;
        private static ThreadPool<Feedback>? pool = null;
        private static WingpanelSound wingpanel_sound = null;

        public static void init () {
            if (instance == null)
                instance = new MediaFeedback ();
        }

        public static void send (string icon, int val)
            requires (instance != null && pool != null) {
            try {
                pool.add (new Feedback (icon, val));
            } catch (ThreadError e) {
            }
        }

        private DBusNotifications? notifications = null;
        private uint32 notification_id = 0;

        private MediaFeedback () {
            Object ();
        }

        construct {
            try {
                pool = new ThreadPool<Feedback>.with_owned_data (send_feedback, 1, false);
            } catch (ThreadError e) {
                critical ("%s", e.message);
                pool = null;
            }

            try {
                Bus.watch_name (SESSION, "org.freedesktop.Notifications", NONE, on_notifications_watch, on_notifications_unwatch);
                Bus.watch_name (SESSION, "io.elementary.wingpanel.sound", NONE, on_wingpanel_sound_watch, on_wingpanel_sound_unwatch);
            } catch (IOError e) {
                debug (e.message);
            }
        }

        private void on_notifications_watch (DBusConnection conn) {
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

        private void on_wingpanel_sound_watch (DBusConnection conn) {
            conn.get_proxy.begin<WingpanelSound> ("io.elementary.wingpanel.sound",
                "/io/elementary/wingpanel/sound", DBusProxyFlags.NONE, null, (obj, res) => {
                    try {
                        wingpanel_sound = ((DBusConnection) obj).get_proxy.end<WingpanelSound> (res);
                    } catch (Error e) {
                        warning (e.message);
                        wingpanel_sound = null;
                    }
            });
        }

        private void on_notifications_unwatch (DBusConnection conn) {
            notifications = null;
        }

        private void on_wingpanel_sound_unwatch (DBusConnection conn) {
            wingpanel_sound = null;
        }

        private void send_feedback (owned Feedback feedback) {
            if (feedback.icon.contains ("audio") && wingpanel_sound != null) {
                try {
                    wingpanel_sound.handle_osd ();
                } catch (Error e) {
                    warning (e.message);
                }

                return;
            }

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
}
