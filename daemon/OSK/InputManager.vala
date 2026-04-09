/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.InputManager : Object {
    public unowned OSKManager osk_manager { get; construct; }

    public InputManager (OSKManager osk_manager) {
        Object (osk_manager: osk_manager);
    }

    public void send_keyval (uint keyval) {
        osk_manager.keyval_pressed (keyval);
        osk_manager.keyval_released (keyval);
    }

    public void erase () {
        osk_manager.keyval_pressed (Gdk.Key.BackSpace);
        osk_manager.keyval_released (Gdk.Key.BackSpace);
    }
}
