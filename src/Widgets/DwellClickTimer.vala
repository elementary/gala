/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2020, 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.DwellClickTimer : Clutter.Actor {
    private float scaling_factor = 1.0f;
    private uint cursor_size = 24;

    private CircularProgressbar progressbar;
    private GLib.Settings interface_settings;

    public Meta.Display display { get; construct; }

    public DwellClickTimer (Meta.Display display) {
        Object (display: display);
    }

    construct {
        visible = false;
        reactive = false;

        interface_settings = new GLib.Settings ("org.gnome.desktop.interface");

        progressbar = new CircularProgressbar ();
        add_child (progressbar);

#if HAS_MUTTER47
        unowned var backend = context.get_backend ();
#else
        unowned var backend = Clutter.get_default_backend ();
#endif
        var seat = backend.get_default_seat ();
        seat.set_pointer_a11y_dwell_click_type (Clutter.PointerA11yDwellClickType.PRIMARY);

        seat.ptr_a11y_timeout_started.connect ((device, type, timeout) => {
            update_cursor_size ();

            unowned var tracker = display.get_cursor_tracker ();
            Graphene.Point coords = {};
            tracker.get_pointer (out coords, null);

            x = coords.x - (width / 2);
            y = coords.y - (width / 2);

            visible = true;
            progressbar.duration = timeout;
            progressbar.start ();
        });

        seat.ptr_a11y_timeout_stopped.connect ((device, type, clicked) => {
            visible = false;
            progressbar.reset ();
        });
    }

    private void update_cursor_size () {
        scaling_factor = display.get_monitor_scale (display.get_current_monitor ());

        cursor_size = (uint) (interface_settings.get_int ("cursor-size") * scaling_factor * 1.25);
        var radius = cursor_size / 2;
        progressbar.radius = radius;

        set_size (cursor_size, cursor_size);
    }
}
