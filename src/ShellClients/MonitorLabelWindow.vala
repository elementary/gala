/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.MonitorLabelWindow : PositionedWindow {
    private const int MARGIN = 24;

    public int monitor_index { get; construct; }

    public MonitorLabelWindow (Meta.Window window, int monitor_index) {
        Object (window: window, monitor_index: monitor_index);
    }

    protected override void get_window_position (Mtk.Rectangle window_rect, out int x, out int y) {
        if (monitor_index < 0 || monitor_index >= window.display.get_n_monitors ()) {
            warning ("Invalid monitor index %d for MonitorLabelWindow, monitor count probably changed", monitor_index);
            x = y = 0;
            return;
        }

        var monitor_rect = window.display.get_monitor_geometry (monitor_index);

        x = monitor_rect.x + MARGIN;
        y = monitor_rect.y + MARGIN;
    }
}
