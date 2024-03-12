/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.Window : Gtk.Window {
    public Gtk.Box content { get; construct; }

    public Window (int width, int height) {
        Object (
            default_width: width,
            default_height: height
        );
    }

    class construct {
        set_css_name ("daemon-window");
    }

    construct {
        decorated = false;
        resizable = false;
        deletable = false;
        can_focus = false;
        input_shape_combine_region (null);
        accept_focus = false;
        skip_taskbar_hint = true;
        skip_pager_hint = true;
        type_hint = Gdk.WindowTypeHint.DOCK;
        set_keep_above (true);

        title = "MODAL";
        child = content = new Gtk.Box (HORIZONTAL, 0) {
            hexpand = true,
            vexpand = true
        };

        set_visual (get_screen ().get_rgba_visual ());

        show_all ();
        move (0, 0);

        button_press_event.connect (() => {
            close ();
            return Gdk.EVENT_STOP;
        });
    }
}
