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

    public override void snapshot (Gtk.Snapshot snapshot) {
        base.snapshot (snapshot);
        // We need to append something here otherwise GTK thinks the snapshot is empty and therefore doesn't
        // render anything and therefore doesn't present a window which is needed for our popovers
        snapshot.append_color ({0, 0, 0, 0}, {{0, 0}, {0, 0}});
    }
}
