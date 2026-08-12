/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.IBusCandidateWindow : PositionedWindow {
    public InputMethod im { get; construct; }

    public IBusCandidateWindow (InputMethod im, Meta.Window window) {
        Object (im: im, window: window);
    }

    construct {
        im.notify["cursor-location"].connect (position_window);
    }

    protected override void get_window_position (Mtk.Rectangle window_rect, out int x, out int y) {
        x = (int) (im.cursor_location.origin.x + im.cursor_location.size.width);
        y = (int) (im.cursor_location.origin.y + im.cursor_location.size.height);
    }
}
