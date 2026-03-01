/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.OSKWindow : PositionedWindow {
    public OSKManager manager { get; construct; }

    public OSKWindow (OSKManager manager, Meta.Window window) {
        Object (manager: manager, window: window);
    }

    protected override void get_window_position (Mtk.Rectangle window_rect, out int x, out int y) {
        x = y = 0;
    }
}
