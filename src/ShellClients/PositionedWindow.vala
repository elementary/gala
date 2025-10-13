/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public abstract class Gala.PositionedWindow : Object {
    public Meta.Window window { get; construct; }

    private ulong position_changed_id;

    construct {
        window.stick ();

        window.size_changed.connect (position_window);
        position_changed_id = window.position_changed.connect (position_window);
        window.shown.connect (position_window);

        unowned var monitor_manager = window.display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (position_window);
        monitor_manager.monitors_changed_internal.connect (position_window);
    }

    private void position_window () {
        var window_rect = window.get_frame_rect ();
        var monitor_rect = window.display.get_monitor_geometry (window.display.get_primary_monitor ());

        int x = 0, y = 0;
        get_window_position (window_rect, monitor_rect, out x, out y);

        SignalHandler.block (window, position_changed_id);
        window.move_frame (false, x, y);
        SignalHandler.unblock (window, position_changed_id);
    }

    protected abstract void get_window_position (
        Mtk.Rectangle window_rect, Mtk.Rectangle monitor_rect, out int x, out int y
    );
}
