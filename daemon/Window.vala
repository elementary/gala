/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.Window : Gtk.Window {
    public Gtk.Popover menu { get; construct; }

    public Window (int width, int height, Gtk.Popover menu) {
        Object (
            default_width: width,
            default_height: height,
            menu: menu
        );
    }

    class construct {
        set_css_name ("daemon-window");
    }

    ~Window () {
        warning ("DESTROY");
        menu.unparent ();
    }

    construct {
        decorated = false;
        resizable = false;
        deletable = false;
        can_focus = false;
        opacity = 0.5;
        //  input_shape_combine_region (null);
        //  accept_focus = false;
        //  skip_taskbar_hint = true;
        //  skip_pager_hint = true;
        //  type_hint = Gdk.WindowTypeHint.DOCK;
        //  set_keep_above (true);

        title = "MODAL";
        child = new Gtk.Box (HORIZONTAL, 0) {
            hexpand = true,
            vexpand = true
        };

        menu.set_parent (this);
        menu.closed.connect (destroy);

        var controller = new Gtk.GestureClick ();
        child.add_controller (controller);
        controller.released.connect (menu.popdown);
    }
}
