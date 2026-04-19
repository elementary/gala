/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.OSKManager : Object {
    public IBusService ibus_service { private get; construct; }

    private OSKService osk_service;
    private OSKWindow? osk_window;

    public OSKManager (IBusService ibus_service) {
        Object (ibus_service: ibus_service);
    }

    construct {
        osk_service = new OSKService ();
        osk_service.notify["osk-enabled"].connect (on_osk_enabled_changed);

        Bus.own_name (SESSION, "io.elementary.OSK", NONE, null, on_name_acquired);
    }

    private void on_name_acquired (DBusConnection connection, string name) {
        try {
            connection.register_object ("/io/elementary/OSK", osk_service);
        } catch (Error e) {
            warning ("Failed to get D-Bus session bus: %s", e.message);
        }
    }

    private void on_osk_enabled_changed () {
        /* If the OSK is active we show the candidates directly in the OSK so disable the popup */
        ibus_service.disable_popup = osk_service.osk_enabled;

        if (!osk_service.osk_enabled) {
            osk_window?.destroy ();
            osk_window = null;
            return;
        }

        var model_manager = new ModelManager (osk_service);
        var input_manager = new InputManager (osk_service);

        osk_window = new OSKWindow (model_manager, input_manager, ibus_service);
        osk_window.present ();
    }
}
