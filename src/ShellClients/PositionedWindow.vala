/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PositionedWindow : Object {
    public enum Position {
        TOP,
        BOTTOM,
        CENTER;

        public static Position from_anchor (Pantheon.Desktop.Anchor anchor) {
            if (anchor > 1) {
                warning ("Position %s not supported yet", anchor.to_string ());
                return CENTER;
            }

            return (Position) anchor;
        }
    }

    public Meta.Window window { get; construct; }
    /**
     * This may only be set after the window was shown.
     * The initial position should only be given in the constructor.
     */
    public Position position { get; construct set; }
    public Variant? position_data { get; construct set; }

    private int width = -1;
    private int height = -1;

    private ulong position_changed_id;

    public PositionedWindow (Meta.Window window, Position position, Variant? position_data = null) {
        Object (window: window, position: position, position_data: position_data);
    }

    construct {
        window.stick ();

        window.size_changed.connect (position_window);
        position_changed_id = window.position_changed.connect (position_window);
        window.shown.connect (position_window);

        unowned var monitor_manager = window.display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (position_window);
        monitor_manager.monitors_changed_internal.connect (position_window);

        notify["position"].connect (position_window);
        notify["position-data"].connect (position_window);
    }

    public Mtk.Rectangle get_custom_window_rect () {
        var window_rect = window.get_frame_rect ();

        if (width > 0) {
            window_rect.width = width;
        }

        if (height > 0) {
            window_rect.height = height;

            if (position == BOTTOM) {
                var geom = window.display.get_monitor_geometry (window.get_monitor ());
                window_rect.y = geom.y + geom.height - height;
            }
        }

        return window_rect;
    }

    public void set_size (int width, int height) {
        this.width = width;
        this.height = height;
    }

    private void position_window () {
        int x = 0, y = 0;
        var window_rect = window.get_frame_rect ();
        unowned var display = window.display;

        switch (position) {
            case CENTER:
                var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
                x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;
                y = monitor_geom.y + (monitor_geom.height - window_rect.height) / 2;
                break;

            case TOP:
                var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
                x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;
                y = monitor_geom.y;
                break;

            case BOTTOM:
                var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
                x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;
                y = monitor_geom.y + monitor_geom.height - window_rect.height;
                break;
        }

        SignalHandler.block (window, position_changed_id);
        window.move_frame (false, x, y);
        SignalHandler.unblock (window, position_changed_id);
    }
}
