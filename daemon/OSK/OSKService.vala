/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

[DBus (name = "io.elementary.OSK")]
public class Gala.Daemon.OSKService : Object {
    public signal void hide_requested ();

    public signal void keyval_pressed (uint keyval);
    public signal void keyval_released (uint keyval);

    private IBusService ibus_service;

    private bool enabled { get { return osk_window != null; } }

    private ModelManager? model_manager;
    private OSKWindow? osk_window;

    internal OSKService (IBusService ibus_service) {
        this.ibus_service = ibus_service;
    }

    public void set_enabled (bool enabled) throws DBusError, IOError {
        if (this.enabled == enabled) {
            return;
        }

        if (enabled) {
            model_manager = new ModelManager ();

            var input_manager = new InputManager (this);

            osk_window = new OSKWindow (model_manager, input_manager, ibus_service);
            osk_window.present ();
        } else {
            osk_window?.destroy ();
            osk_window = null;
            model_manager = null;
        }
    }

    /**
     * Called for example when the keyboard is dismissed.
     */
    public void reset () throws DBusError, IOError requires (osk_window != null) {
        osk_window.reset ();
    }

    public void set_input_purpose (IBus.InputPurpose input_purpose) throws DBusError, IOError requires (model_manager != null) {
        model_manager.input_purpose = input_purpose;
    }
}
