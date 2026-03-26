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

        osk = new OSKWindow ();

        osk.keyval_pressed.connect (on_keyval_pressed);
        osk.keyval_released.connect (on_keyval_released);

        osk.present ();
    }

    private void on_keyval_pressed (uint keyval) {
        keyval_pressed (keyval);
    }

    private void on_keyval_released (uint keyval) {
        keyval_released (keyval);
    }
}
