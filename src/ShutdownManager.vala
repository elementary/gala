/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.ShutdownManager : Object {
    public ScreenShield screen_shield { private get; construct; }

    private LoginManager? login_manager;
    private UnixInputStream? inhibitor;

    public ShutdownManager (ScreenShield screen_shield) {
        Object (screen_shield: screen_shield);
    }

    construct {
        setup_dbus_interface.begin ();
    }

    private async void setup_dbus_interface () {
        try {
            login_manager = yield Bus.get_proxy (BusType.SYSTEM, "org.freedesktop.login1", "/org/freedesktop/login1");
            inhibit_shutdown ();

            login_manager.prepare_for_shutdown.connect ((about_to_shutdown) => {
                if (!about_to_shutdown) {
                    return;
                }

                screen_shield.activate (300, remove_inhibitor);
            });
        } catch (Error e) {
            warning ("Couldn't get login manager: %s", e.message);
        }
    }

    private void inhibit_shutdown () requires (login_manager != null && inhibitor == null) {
        try {
            inhibitor = login_manager.inhibit ("shutdown", "Pantheon", "Pantheon needs to play shutdown animation", "delay");
        } catch (Error e) {
            warning ("Couldn't inhibit shutdown, no shutdown animation will be player: %s", e.message);
        }
    }

    private void remove_inhibitor () requires (inhibitor != null) {
        try {
            inhibitor.close ();
        } catch (Error e) {
            warning ("Couldn't remove shutdown inhibitor: %s", e.message);
        }
    }
}
