/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Gala.WindowGrabTracker : GLib.Object {
    public Meta.Display display { get; construct; }
    public Meta.Window? current_window { get; private set; }

    public WindowGrabTracker (Meta.Display display) {
        Object (display: display);
    }

    construct {
        display.grab_op_begin.connect (on_grab_op_begin);
        display.grab_op_end.connect (on_grab_op_end);
    }

    private void on_grab_op_begin (Meta.Window window, Meta.GrabOp op) {
        if (op != MOVING) {
            return;
        }

        current_window = window;
    }

    private void on_grab_op_end (Meta.Window window, Meta.GrabOp op) {
        current_window = null;
    }
}
