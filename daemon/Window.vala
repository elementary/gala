/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.Window : Gtk.Window {
    class construct {
        set_css_name ("daemon-window");
    }

    construct {
        decorated = false;
        resizable = false;
        deletable = false;
        can_focus = false;
        opacity = 0.5;
        title = "MODAL";
        hide_on_close = true;
        child = new Gtk.Box (HORIZONTAL, 0) {
            hexpand = true,
            vexpand = true
        };

        var controller = new Gtk.GestureClick ();
        child.add_controller (controller);
        controller.released.connect (close);
    }
}
