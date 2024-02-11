/*
 * Copyright 2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.Window : Gtk.Window {
    static construct {
        var app_provider = new Gtk.CssProvider ();
        app_provider.load_from_resource ("io/elementary/desktop/gala-daemon/gala-daemon.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), app_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    public bool close_on_click { get; construct; }
    public Gtk.Box content { get; construct; }

    public Window (int width, int height, bool close_on_click) {
        Object (
            default_width: width,
            default_height: height,
            close_on_click: close_on_click
        );
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

        opacity = 0;

        child = content = new Gtk.Box (HORIZONTAL, 0) {
            hexpand = true,
            vexpand = true
        };

        set_visual (get_screen ().get_rgba_visual ());

        show_all ();
        move (0, 0);

        if (close_on_click) {
            button_press_event.connect (() => {
                close ();
                return Gdk.EVENT_STOP;
            });
        }
    }
}
