//
//  Copyright (C) 2020 elementary, Inc. (https://elementary.io)
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
    [DBus (name = "org.freedesktop.login1.Manager")]
    interface LoginManager : Object {
        public signal void prepare_for_sleep (bool about_to_suspend);

        public abstract GLib.ObjectPath get_session (string session_id) throws GLib.Error;

        public abstract UnixInputStream inhibit (string what, string who, string why, string mode) throws GLib.Error;
    }

    [DBus (name = "org.freedesktop.login1.Session")]
    interface LoginSessionManager : Object {
        public abstract bool active { get; }

        public signal void lock ();
        public signal void unlock ();

        public abstract void set_locked_hint (bool locked) throws GLib.Error;
    }

    struct LoginDisplay {
        string session;
        GLib.ObjectPath objectpath;
    }

    [DBus (name = "org.freedesktop.login1.User")]
    interface LoginUserManager : Object {
        public abstract LoginDisplay? display { owned get; }
    }

    enum PresenceStatus {
        AVAILABLE = 0,
        INVISIBLE = 1,
        BUSY = 2,
        IDLE = 3
    }

    [DBus (name = "org.gnome.SessionManager.Presence")]
    interface SessionPresence : Object {
        public abstract uint status { get; }
        public signal void status_changed (uint new_status);
    }

    [DBus (name = "org.freedesktop.DisplayManager.Seat")]
    interface DisplayManagerSeat : Object {
        public abstract void switch_to_greeter ();
    }

    public class ScreenShield : Clutter.Actor {
        public const string LOCK_ENABLED_KEY = "lock-enabled";
        public const string LOCK_PROHIBITED_KEY = "disable-lock-screen";

        public signal void active_changed ();
        public signal void wake_up_screen ();

        public bool active { get; private set; default = false; }
        public bool is_locked { get; private set; default = false; }
        public bool in_greeter { get; private set; default = false; }
        public int64 activation_time  { get; private set; default = 0; }

        public WindowManager wm { get; construct; }

        private ModalProxy? modal_proxy;

        private LoginManager? login_manager;
        private LoginUserManager? login_user_manager;
        private LoginSessionManager? login_session;
        private SessionPresence? session_presence;

        private DisplayManagerSeat? display_manager;

        private Meta.IdleMonitor idle_monitor;
        private uint became_active_id = 0;

        private UnixInputStream? inhibitor;

        private GLib.Settings screensaver_settings;
        private GLib.Settings lockdown_settings;

        public ScreenShield (WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            visible = false;
            reactive = true;

            key_press_event.connect ((event) => {
                on_user_became_active ();
            });

            motion_event.connect ((event) => {
                on_user_became_active ();
            });

            background_color = Clutter.Color.from_string ("black");

            expand_to_screen_size ();

            idle_monitor = Meta.IdleMonitor.get_core ();

            login_manager = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.login1", "/org/freedesktop/login1");
            login_user_manager = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.login1", "/org/freedesktop/login1/user/self");

            if (login_manager != null) {
                login_manager.prepare_for_sleep.connect (prepare_for_sleep);
                login_session = get_current_session_manager ();
                if (login_session != null) {
                    login_session.lock.connect (() => @lock (false));
                    login_session.unlock.connect (() => {
                        deactivate (false);
                        in_greeter = false;
                    });

                    login_session.notify.connect (sync_inhibitor);
                    sync_inhibitor ();
                }
            }

            session_presence = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.SessionManager", "/org/gnome/SessionManager/Presence");
            if (session_presence != null) {
                on_status_changed ((PresenceStatus)session_presence.status);
                session_presence.status_changed.connect ((status) => on_status_changed ((PresenceStatus)status));
            }

            string? seat_path = GLib.Environment.get_variable ("XDG_SEAT_PATH");
            if (seat_path != null) {
                display_manager = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.DisplayManager", seat_path);
            }

            screensaver_settings = new GLib.Settings ("org.gnome.desktop.screensaver");
            lockdown_settings = new GLib.Settings ("org.gnome.desktop.lockdown");
        }

        public void expand_to_screen_size () {
            int screen_width, screen_height;
#if HAS_MUTTER330
            wm.get_display ().get_size (out screen_width, out screen_height);
#else
            wm.get_screen ().get_size (out screen_width, out screen_height);
#endif
            width = screen_width;
            height = screen_height;
        }

        private void prepare_for_sleep (bool about_to_suspend) {
            if (about_to_suspend) {
                if (screensaver_settings.get_boolean (LOCK_ENABLED_KEY)) {
                    debug ("about to sleep, locking screen");
                    this.@lock (true);
                }
            } else {
                debug ("resumed from suspend, waking screen");
                trigger_wake_up_screen ();
            }
        }

        private void on_status_changed (PresenceStatus status) {
            if (status != PresenceStatus.IDLE) {
                return;
            }

            debug ("session became idle, activating screensaver");

            activate (true);

            if (screensaver_settings.get_boolean (LOCK_ENABLED_KEY)) {
                debug ("locking enabled, also locking screen");
                this.@lock (true);
            }
        }

        private void trigger_wake_up_screen () {
            on_user_became_active ();
            wake_up_screen ();
            expand_to_screen_size ();
        }

        private void sync_inhibitor () {
            var lock_enabled = screensaver_settings.get_boolean (LOCK_ENABLED_KEY);
            var lock_prohibited = lockdown_settings.get_boolean (LOCK_PROHIBITED_KEY);

            var inhibit = login_session != null && login_session.active && !active && lock_enabled && !lock_prohibited;
            if (inhibit) {
                var new_inhibitor = login_manager.inhibit ("sleep", "Pantheon", "Pantheon needs to lock the screen", "delay");
                if (inhibitor != null) {
                    inhibitor.close ();
                    inhibitor = null;
                }

                inhibitor = new_inhibitor;
            } else {
                if (inhibitor != null) {
                    inhibitor.close ();
                    inhibitor = null;
                }
            }
        }

        private void on_user_became_active () {
            if (became_active_id != 0) {
                idle_monitor.remove_watch (became_active_id);
                became_active_id = 0;
            }

            if (is_locked && !in_greeter) {
                debug ("user became active, switching to greeter");
                display_manager.switch_to_greeter ();
                in_greeter = true;
            } else if (!is_locked) {
                debug ("user became active in unlocked session, closing screensaver");
                deactivate (false);
            }
        }

        private LoginSessionManager? get_current_session_manager () {
            string? session_id = GLib.Environment.get_variable ("XDG_SESSION_ID");
            if (session_id == null) {
                debug ("Unset XDG_SESSION_ID, asking logind");
                if (login_user_manager == null) {
                    return null;
                }

                session_id = login_user_manager.display.session;
            }

            if (session_id == null) {
                return null;
            }

            var session_path = login_manager.get_session (session_id);
            LoginSessionManager? session = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.login1", session_path);

            return session;
        }

        public void @lock (bool animate) {
            if (is_locked) {
                return;
            }

            if (lockdown_settings.get_boolean (LOCK_PROHIBITED_KEY)) {
                debug ("Lock prohibited, ignoring lock request");
                return;
            }

            is_locked = true;

            activate (animate);
        }

        public void activate (bool animate) {
            if (visible) {
                return;
            }

            expand_to_screen_size ();

            if (activation_time == 0) {
                activation_time = GLib.get_monotonic_time ();
            }

#if HAS_MUTTER330
            wm.get_display ().get_cursor_tracker ().set_pointer_visible (false);
#else
            wm.get_display ().get_cursor_tracker ().set_pointer_visible (false);
#endif

            visible = true;
            grab_key_focus ();
            modal_proxy = wm.push_modal ();

            _set_active (true);

            if (screensaver_settings.get_boolean (LOCK_ENABLED_KEY)) {
                @lock (false);
            }

            // if (became_active_id == 0) {
            //     became_active_id = idle_monitor.add_user_active_watch (() => on_user_became_active ());
            // }
        }

        public void deactivate (bool animate) {
            is_locked = false;

            if (modal_proxy != null) {
                wm.pop_modal (modal_proxy);
                modal_proxy = null;
            }

#if HAS_MUTTER330
            wm.get_display ().get_cursor_tracker ().set_pointer_visible (true);
#else
            wm.get_display ().get_cursor_tracker ().set_pointer_visible (true);
#endif

            visible = false;

            wake_up_screen ();

            activation_time = 0;
            _set_active (false);
        }

        private void _set_active (bool new_active) {
            var prev_is_active = active;
            active = new_active;

            if (prev_is_active != active) {
                active_changed ();
            }

            sync_inhibitor ();
        }
    }
}
