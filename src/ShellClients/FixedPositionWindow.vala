/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.FixedPositionWindow : ShellWindow {
    public Mtk.Rectangle position { get; construct; }

    public FixedPositionWindow (Meta.Window window, Mtk.Rectangle position) {
        var target = new PropertyTarget (CUSTOM, window.get_compositor_private (), "opacity", typeof (uint), 255u, 0u);
        Object (window: window, hide_target: target, position: position);
    }

    protected override void get_window_position (Mtk.Rectangle window_rect, out int x, out int y) {
        x = position.x;
        y = position.y;
    }
}
