/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ExtendedBehaviorWindow : ShellWindow {
    public ExtendedBehaviorWindow (Meta.Window window) {
        var target = new PropertyTarget (CUSTOM, window.get_compositor_private (), "opacity", typeof (uint), 255u, 0u);
        Object (window: window, position: Position.CENTER, hide_target: target);
    }
}
