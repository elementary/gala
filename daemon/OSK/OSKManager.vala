/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

[DBus (name = "io.elementary.OSK")]
public class Gala.Daemon.OSKManager : Object {
    public signal void keyval_pressed (uint keyval);
    public signal void keyval_released (uint keyval);

    private OSKWindow? osk;

    public async void set_enabled (bool enabled) throws DBusError, IOError {
        if (!enabled) {
            osk?.destroy ();
            osk = null;
            return;
        }

        var model_manager = new ModelManager ();
        var input_manager = new InputManager (this);

        osk = new OSKWindow (model_manager, input_manager);
        osk.present ();
    }

    public async void set_input_purpose () throws DBusError, IOError {
        //  model_manager.set_input_purpose (input_purpose);
    }
}
