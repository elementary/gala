/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ExtendedBehaviorWindow : ShellWindow {
    public bool centered { get; set; default = false; }
    public bool modal { get; private set; default = false; }
    public bool dim { get; private set; default = false; }

    public ExtendedBehaviorWindow (Meta.Window window) {
        var target = new PropertyTarget (CUSTOM, window.get_compositor_private (), "opacity", typeof (uint), 255u, 0u);
        Object (window: window, hide_target: target);
    }

    public void make_modal (bool dim) {
        modal = true;
        this.dim = dim;
    }

    protected override void get_window_position (Mtk.Rectangle window_rect, out int x, out int y) {
        if (!centered) {
            x = window_rect.x;
            y = window_rect.y;
            return;
        }

        var monitor_rect = window.display.get_monitor_geometry (window.get_monitor ());

        x = monitor_rect.x + (monitor_rect.width - window_rect.width) / 2;
        y = monitor_rect.y + (monitor_rect.height - window_rect.height) / 2;
    }
}
