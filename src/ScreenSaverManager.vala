/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2020, 2025 elementary, Inc. (https://elementary.io)
 */

[DBus (name="org.gnome.ScreenSaver")]
public class Gala.ScreenSaverManager : Object {
    public signal void active_changed (bool new_value);

    [DBus (visible = false)]
    public ScreenShield screen_shield { get; construct; }

    public ScreenSaverManager (ScreenShield shield) {
        Object (screen_shield: shield);
    }

    construct {
        screen_shield.active_changed.connect (() => {
            active_changed (screen_shield.active);
        });
    }

    public void @lock () throws GLib.Error {
        screen_shield.@lock (true);
    }

    public bool get_active () throws GLib.Error {
        return screen_shield.active;
    }

    public void set_active (bool active) throws GLib.Error {
        if (active) {
            screen_shield.activate (true);
        } else {
            screen_shield.deactivate (false);
        }
    }

    public uint get_active_time () throws GLib.Error {
        var started = screen_shield.activation_time;
        if (started > 0) {
            return (uint)Math.floor ((GLib.get_monotonic_time () - started) / 1000000);
        } else {
            return 0;
        }
    }
}
