/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.CenteredWindow : Object {
    public WindowManager wm { get; construct; }
    public Meta.Window window { get; construct; }

    public CenteredWindow (WindowManager wm, Meta.Window window) {
        Object (wm: wm, window: window);
    }

    construct {
        window.size_changed.connect (position_window);
        window.stick ();

        var monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (() => position_window ());

        position_window ();

        window.shown.connect (() => window.focus (wm.get_display ().get_current_time ()));
    }

    private void position_window () {
        var display = wm.get_display ();
        var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
        var window_rect = window.get_frame_rect ();

        var x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;
        var y = monitor_geom.y + (monitor_geom.height - window_rect.height) / 2;

        Idle.add (() => {
            window.move_frame (false, x, y);
            return Source.REMOVE;
        });
    }
}
