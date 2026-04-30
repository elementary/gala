/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * Once the OSK is enabled the Manager creates a receiver which handles the input received from
 * the OSK and forwards it.
 */
public class Gala.OSKReceiver : Object {
    public Meta.Display display { private get; construct; }
    public OSKProxy osk { private get; construct; }
    public InputMethod im { private get; construct; }

    private Clutter.VirtualInputDevice virtual_device;

    public OSKReceiver (Meta.Display display, OSKProxy osk, InputMethod im) {
        Object (display: display, osk: osk, im: im);
    }

    construct {
        var seat = Clutter.get_default_backend ().get_default_seat ();
        virtual_device = seat.create_virtual_device (KEYBOARD_DEVICE);

        osk.keyval_pressed.connect (on_keyval_pressed);
        osk.keyval_released.connect (on_keyval_released);
    }

    private void on_keyval_pressed (uint keyval) {
        virtual_device.notify_keyval (Clutter.get_current_event_time () * 1000, keyval, PRESSED);
    }

    private void on_keyval_released (uint keyval) {
        virtual_device.notify_keyval (Clutter.get_current_event_time () * 1000, keyval, RELEASED);
    }
}
