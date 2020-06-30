//
//  Copyright (c) 2018 elementary LLC. (https://elementary.io)
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
    [DBus (name = "org.gnome.SessionManager")]
    public interface SessionManager : Object {
        public abstract async ObjectPath register_client (
            string app_id,
            string client_start_id
        ) throws DBusError, IOError;
    }

    [DBus (name = "org.gnome.SessionManager.ClientPrivate")]
    public interface SessionClient : Object {
        public abstract void end_session_response (bool is_ok, string reason) throws DBusError, IOError;

        public signal void stop () ;
        public signal void query_end_session (uint flags);
        public signal void end_session (uint flags);
        public signal void cancel_end_session ();
    }

    [DBus (name = "io.elementary.pantheon.AccountsService")]
    private interface PantheonShell.Pantheon.AccountsService : Object {
        public abstract int prefers_color_scheme { get; set; }
    }

    public class Daemon {
        SessionClient? sclient = null;

        public Daemon () {
            register.begin ((o, res)=> {
                bool success = register.end (res);
                if (!success) {
                    message ("Failed to register with Session manager");
                }
            });

            var menu_daemon = new MenuDaemon ();
            menu_daemon.setup_dbus ();
        }

        public void run () {
            Gtk.main ();
        }

        public static async SessionClient? register_with_session (string app_id) {
            ObjectPath? path = null;
            string? msg = null;
            string? start_id = null;

            SessionManager? session = null;
            SessionClient? session_client = null;

            start_id = Environment.get_variable ("DESKTOP_AUTOSTART_ID");
            if (start_id != null) {
                Environment.unset_variable ("DESKTOP_AUTOSTART_ID");
            } else {
                start_id = "";
                warning (
                    "DESKTOP_AUTOSTART_ID not set, session registration may be broken (not running via session?)"
                );
            }

            try {
                session = yield Bus.get_proxy (
                    BusType.SESSION,
                    "org.gnome.SessionManager",
                    "/org/gnome/SessionManager"
                );
            } catch (Error e) {
                warning ("Unable to connect to session manager: %s", e.message);
                return null;
            }

            try {
                path = yield session.register_client (app_id, start_id);
            } catch (Error e) {
                msg = e.message;
                warning ("Error registering with session manager: %s", e.message);
                return null;
            }

            try {
                session_client = yield Bus.get_proxy (BusType.SESSION, "org.gnome.SessionManager", path);
            } catch (Error e) {
                warning ("Unable to get private sessions client proxy: %s", e.message);
                return null;
            }

            return session_client;
        }

        async bool register () {
            sclient = yield register_with_session ("org.pantheon.gala.daemon");

            sclient.query_end_session.connect (() => end_session (false));
            sclient.end_session.connect (() => end_session (false));
            sclient.stop.connect (() => end_session (true));

            return true;
        }

        void end_session (bool quit) {
            if (quit) {
                Gtk.main_quit ();
                return;
            }

            try {
                sclient.end_session_response (true, "");
            } catch (Error e) {
                warning ("Unable to respond to session manager: %s", e.message);
            }
        }
    }

    public enum State {
        UNKNOWN,
        IN,
        OUT
    }

    public State get_state (double time_double, from, to) {
        if (from >= 0.0 && time_double >= from || time_double >= 0.0 && time_double < to) {
            return State.IN;
        }

        return State.OUT;
    }

    public double date_time_double (DateTime date_time) {
        double time_double = 0;
        time_double += date_time.get_hour ();
        time_double += (double) date_time.get_minute () / 60;

        return time_double;
    }

    public static int main (string[] args) {
        Gtk.init (ref args);

        var ctx = new OptionContext ("Gala Daemon");
        ctx.set_help_enabled (true);
        ctx.add_group (Gtk.get_option_group (false));

        try {
            ctx.parse (ref args);
        } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
            return 0;
        }

        var time = new TimeoutSource (1000);

        var state = State.UNKNOWN;
        var settings = new GLib.Settings ("io.elementary.settings-daemon.plugins.color");

        PantheonShell.Pantheon.AccountsService? pantheon_act = null;
        string? user_path = null;
        try {
            FDO.Accounts? accounts_service = GLib.Bus.get_proxy_sync (
                GLib.BusType.SYSTEM,
               "org.freedesktop.Accounts",
               "/org/freedesktop/Accounts"
            );

            user_path = accounts_service.find_user_by_name (GLib.Environment.get_user_name ());
        } catch (Error e) {
            critical (e.message);
        }

        if (user_path != null) {
            try {
                pantheon_act = GLib.Bus.get_proxy_sync (
                    GLib.BusType.SYSTEM,
                    "org.freedesktop.Accounts",
                    user_path,
                    GLib.DBusProxyFlags.GET_INVALIDATED_PROPERTIES
                );
            } catch (Error e) {
                warning ("Unable to get AccountsService proxy, color scheme preference may be incorrect");
            }
        }

        time.set_callback (() => {
            var schedule = settings.get_string ("prefer-dark-schedule");

            double from, to;
            if (schedule == "sunset-to-sunrise") {
                from = 20.0;
                to = 6.0;
            } else if (schedule == "manual") {
                from = settings.get_double ("prefer-dark-schedule-from");
                to = settings.get_double ("prefer-dark-schedule-to");
            } else {
                return true;
            }

            var now = new DateTime.now_local ();

            var new_state = get_state (date_time_double (now, from, to));
            if (new_state != state) {
                switch (new_state) {
                    case State.IN:
                        pantheon_act.prefers_color_scheme = Granite.Settings.ColorScheme.DARK;
                        break;
                    case State.OUT:
                        pantheon_act.prefers_color_scheme = Granite.Settings.ColorScheme.NO_PREFERENCE;
                        break;
                    default:
                        break;
                }

                state = new_state;
            }

            return true;
        });

        time.attach (null);

        var daemon = new Daemon ();
        daemon.run ();

        return 0;
    }
}
