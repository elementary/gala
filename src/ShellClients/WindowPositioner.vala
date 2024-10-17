/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WindowPositioner : Object {
    public delegate void PositionFunc (ref int x, ref int y);

    public Meta.Window window { get; construct; }
    public WindowManager wm { get; construct; }

    private PositionFunc position_func;

    public WindowPositioner (Meta.Window window, WindowManager wm, owned PositionFunc position_func) {
        Object (window: window, wm: wm);

        this.position_func = (owned) position_func;
    }

    construct {
        window.stick ();

        window.size_changed.connect (position_window);
        window.position_changed.connect (position_window);
        window.shown.connect (position_window);

        var monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (position_window);
        monitor_manager.monitors_changed_internal.connect (position_window);
    }

    private void position_window () {
        int x = 0, y = 0;
        position_func (ref x, ref y);

        window.move_frame (false, x, y);
    }
}
