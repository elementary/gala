/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2020, 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.SessionLocker : Object {
    [DBus (name = "org.freedesktop.login1.Session")]
    private interface LoginSessionManager : Object {
        public abstract bool active { get; }

        public signal void lock ();
        public signal void unlock ();

        public abstract void set_locked_hint (bool locked) throws GLib.Error;
    }

    private struct LoginDisplay {
        string session;
        GLib.ObjectPath objectpath;
    }

    [DBus (name = "org.freedesktop.login1.User")]
    private interface LoginUserManager : Object {
        public abstract LoginDisplay? display { owned get; }
    }

    [CCode (type_signature = "u")]
    private enum PresenceStatus {
        AVAILABLE = 0,
        INVISIBLE = 1,
        BUSY = 2,
        IDLE = 3
    }

    [DBus (name = "org.gnome.SessionManager.Presence")]
    private interface SessionPresence : Object {
        public abstract PresenceStatus status { get; }
        public signal void status_changed (PresenceStatus new_status);
    }

    [DBus (name = "org.freedesktop.DisplayManager.Seat")]
    private interface DisplayManagerSeat : Object {
        public abstract void switch_to_greeter () throws GLib.Error;
    }

    // Animation length for when computer has been sitting idle and display
    // is about to turn off
    public const uint LONG_ANIMATION_TIME = 3000;
    // Animation length used for manual lock action (i.e. Super+L or GUI action)
    public const uint SHORT_ANIMATION_TIME = 300;

    private const string LOCK_ENABLED_KEY = "lock-enabled";
    private const string LOCK_PROHIBITED_KEY = "disable-lock-screen";
    private const string LOCK_ON_SUSPEND_KEY = "lock-on-suspend";

    public ScreenShield screen_shield { private get; construct; }

    public int64 activation_time { get; private set; default = 0; }

    // Screensaver active but not necessarily locked
    private bool _active = false;
    public bool active {
        get {
            return _active;
        }
        private set {
            if (!connected_to_buses) {
                return;
            }

            if (_active != value) {
                _active = value;
                notify_property ("active");
            }

            try {
                login_session.set_locked_hint (active);
            } catch (Error e) {
                warning ("Unable to set locked hint on login session: %s", e.message);
            }

            sync_inhibitor ();
        }
    }

    private LoginManager? login_manager;
    private LoginUserManager? login_user_manager;
    private LoginSessionManager? login_session;
    private SessionPresence? session_presence;
    private DisplayManagerSeat? display_manager;

    private UnixInputStream? inhibitor;

    private GLib.Settings screensaver_settings;
    private GLib.Settings lockdown_settings;
    private GLib.Settings gala_settings;

    private bool connected_to_buses = false;
    private bool is_locked = false;
    private bool in_greeter = false;

    public SessionLocker (ScreenShield screen_shield) {
        Object (screen_shield: screen_shield);
    }

    construct {
        // We use the lock-enabled key in the GNOME namespace instead of our own
        // because it's also used by gsd-power
        screensaver_settings = new GLib.Settings ("org.gnome.desktop.screensaver");

        // Vanilla GNOME doesn't have a key that separately enables/disables locking on
        // suspend, so we have a key in our own namespace for this
        gala_settings = new GLib.Settings ("io.elementary.desktop.screensaver");
        lockdown_settings = new GLib.Settings ("org.gnome.desktop.lockdown");

        screen_shield.user_action.connect (on_user_became_active);

        init_dbus_interfaces.begin ();
    }

    private async void init_dbus_interfaces () {
        bool success = true;

        try {
            login_manager = yield Bus.get_proxy (BusType.SYSTEM, "org.freedesktop.login1", "/org/freedesktop/login1");
            login_user_manager = yield Bus.get_proxy (BusType.SYSTEM, "org.freedesktop.login1", "/org/freedesktop/login1/user/self");

            // Listen for sleep/resume events from logind
            login_manager.prepare_for_sleep.connect (prepare_for_sleep);
            login_session = get_current_session_manager ();
            if (login_session != null) {
                // Listen for lock unlock events from logind
                login_session.lock.connect (() => @lock (false));
                login_session.unlock.connect (() => {
                    deactivate ();
                    in_greeter = false;
                });

                ((DBusProxy)login_session).g_properties_changed.connect (sync_inhibitor);
                sync_inhibitor ();
            }
        } catch (Error e) {
            success = false;
            critical ("Unable to connect to logind bus, screen locking disabled: %s", e.message);
        }

        try {
            session_presence = yield Bus.get_proxy (BusType.SESSION, "org.gnome.SessionManager", "/org/gnome/SessionManager/Presence");
            on_status_changed (session_presence.status);
            session_presence.status_changed.connect ((status) => on_status_changed (status));
        } catch (Error e) {
            success = false;
            critical ("Unable to connect to session presence bus, screen locking disabled: %s", e.message);
        }


        string? seat_path = GLib.Environment.get_variable ("XDG_SEAT_PATH");
        if (seat_path != null) {
            try {
                display_manager = yield Bus.get_proxy (BusType.SYSTEM, "org.freedesktop.DisplayManager", seat_path);
            } catch (Error e) {
                success = false;
                critical ("Unable to connect to display manager bus, screen locking disabled");
            }
        } else {
            success = false;
            critical ("XDG_SEAT_PATH unset, screen locking disabled");
        }

        connected_to_buses = success;
    }

    private void prepare_for_sleep (bool about_to_suspend) {
        if (!connected_to_buses) {
            return;
        }

        if (about_to_suspend) {
            if (gala_settings.get_boolean (LOCK_ON_SUSPEND_KEY)) {
                debug ("about to sleep, locking screen");
                this.@lock (false);
            }
        } else {
            debug ("resumed from suspend, waking screen");
            on_user_became_active ();
        }
    }

    // status becomes idle after interval defined at /org/gnome/desktop/session/idle-delay
    private void on_status_changed (PresenceStatus status) {
        if (status != PresenceStatus.IDLE || !connected_to_buses) {
            return;
        }

        debug ("session became idle, activating screensaver");

        activate (true);
    }

    // We briefly inhibit sleep so that we can try and lock before sleep occurs if necessary
    private void sync_inhibitor () {
        if (!connected_to_buses) {
            return;
        }

        var lock_enabled = gala_settings.get_boolean (LOCK_ON_SUSPEND_KEY);
        var lock_prohibited = lockdown_settings.get_boolean (LOCK_PROHIBITED_KEY);

        var inhibit = login_session != null && login_session.active && !active && lock_enabled && !lock_prohibited;
        if (inhibit) {
            try {
                var new_inhibitor = login_manager.inhibit ("sleep", "Pantheon", "Pantheon needs to lock the screen", "delay");
                if (inhibitor != null) {
                    inhibitor.close ();
                    inhibitor = null;
                }

                inhibitor = new_inhibitor;
            } catch (Error e) {
                warning ("Unable to inhibit sleep, may be unable to lock before sleep starts: %s", e.message);
            }
        } else {
            if (inhibitor != null) {
                try {
                    inhibitor.close ();
                } catch (Error e) {
                    warning ("Unable to remove sleep inhibitor: %s", e.message);
                }

                inhibitor = null;
            }
        }
    }

    private void on_user_became_active () {
        if (!connected_to_buses) {
            return;
        }

        // User became active in some way, switch to the greeter if we're not there already
        if (is_locked && !in_greeter) {
            debug ("user became active, switching to greeter");
            deactivate ();
            try {
                display_manager.switch_to_greeter ();
                in_greeter = true;
            } catch (Error e) {
                critical ("Unable to switch to greeter to unlock: %s", e.message);
            }
        // Otherwise, we're in screensaver mode, just deactivate
        } else if (!is_locked) {
            debug ("user became active in unlocked session, closing screensaver");
            deactivate ();
        }
    }

    private LoginSessionManager? get_current_session_manager () throws GLib.Error {
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
        if (is_locked || !connected_to_buses) {
            return;
        }

        if (lockdown_settings.get_boolean (LOCK_PROHIBITED_KEY)) {
            debug ("Lock prohibited, ignoring lock request");
            return;
        }

        is_locked = true;

        activate (animate, SHORT_ANIMATION_TIME);
    }

    public void activate (bool animate, uint animation_time = LONG_ANIMATION_TIME) {
        if (active || !connected_to_buses) {
            return;
        }

        if (activation_time == 0) {
            activation_time = GLib.get_monotonic_time ();
        }

        screen_shield.activate (animate ? 0 : animation_time, () => {
            active = true;

            if (screensaver_settings.get_boolean (LOCK_ENABLED_KEY)) {
                @lock (false);
            }
        });
    }

    public void deactivate () {
        if (!connected_to_buses) {
            return;
        }

        screen_shield.deactivate ();

        is_locked = false;
        activation_time = 0;
        active = false;
    }
}
