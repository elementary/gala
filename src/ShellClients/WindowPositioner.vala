/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WindowPositioner : Object {
    public enum Position {
        CENTER
    }

    public Meta.Display display { get; construct; }
    public Meta.Window window { get; construct; }
    public Position position { get; private set; }
    public Variant? position_data { get; private set; }

    public WindowPositioner (Meta.Display display, Meta.Window window, Position position, Variant? position_data = null) {
        Object (display: display, window: window, position: position, position_data: position_data);
    }

    construct {
        window.stick ();

        window.size_changed.connect (position_window);
        window.position_changed.connect (position_window);
        window.shown.connect (position_window);

        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (position_window);
        monitor_manager.monitors_changed_internal.connect (position_window);
    }

    /**
     * This may only be called after the window was shown.
     */
    public void update_position (Position new_position, Variant? new_position_data = null) {
        position = new_position;
        position_data = new_position_data;

        position_window ();
    }

    private void position_window () {
        int x = 0, y = 0;

        switch (position) {
            case CENTER:
                var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
                var window_rect = window.get_frame_rect ();

                x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;
                y = monitor_geom.y + (monitor_geom.height - window_rect.height) / 2;
                break;
        }

        window.move_frame (false, x, y);
    }
}
