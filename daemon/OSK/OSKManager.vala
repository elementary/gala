/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.OSKManager : Object {
    public IBusService ibus_service { private get; construct; }

    private OSKService osk_service;

    public OSKManager (IBusService ibus_service) {
        Object (ibus_service: ibus_service);
    }

    construct {
        osk_service = new OSKService (ibus_service);

        Bus.own_name (SESSION, "io.elementary.OSK", NONE, null, on_name_acquired);
    }

    private void on_name_acquired (DBusConnection connection, string name) {
        try {
            connection.register_object ("/io/elementary/OSK", osk_service);
        } catch (Error e) {
            warning ("Failed to get D-Bus session bus: %s", e.message);
        }
    }
}
