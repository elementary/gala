/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2020, 2025 elementary, Inc. (https://elementary.io)
 */

[DBus (name="org.gnome.ScreenSaver")]
public class Gala.ScreenSaverManager : Object {
    public signal void active_changed (bool new_value);

    [DBus (visible = false)]
    public SessionLocker session_locker { get; construct; }

    public ScreenSaverManager (SessionLocker session_locker) {
        Object (session_locker: session_locker);
    }

    construct {
        session_locker.notify["active"].connect (() => {
            active_changed (session_locker.active);
        });
    }

    public void @lock () throws GLib.Error {
        session_locker.@lock (true);
    }

    public bool get_active () throws GLib.Error {
        return session_locker.active;
    }

    public void set_active (bool active) throws GLib.Error {
        if (active) {
            session_locker.activate (true);
        } else {
            session_locker.deactivate ();
        }
    }

    public uint get_active_time () throws GLib.Error {
        var started = session_locker.activation_time;
        if (started > 0) {
            return (uint)Math.floor ((GLib.get_monotonic_time () - started) / 1000000);
        } else {
            return 0;
        }
    }
}
