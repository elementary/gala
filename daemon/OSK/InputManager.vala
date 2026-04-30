/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.InputManager : Object {
    public OSKService service { private get; construct; }

    public InputManager (OSKService service) {
        Object (service: service);
    }

    public void send_keyval (uint keyval) {
        service.keyval_pressed (keyval);
        service.keyval_released (keyval);
    }

    public void erase () {
        service.keyval_pressed (Gdk.Key.BackSpace);
        service.keyval_released (Gdk.Key.BackSpace);
    }
}
