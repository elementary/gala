/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.OSKWindow : ShellWindow, RootTarget {
    public OSKManager manager { private get; construct; }

    public Clutter.Actor? actor { get { return (Clutter.Actor) window.get_compositor_private (); } }

    private GestureController gesture_controller;

    public OSKWindow (OSKManager manager, Meta.Window window) {
        Object (manager: manager, window: window);
    }

    construct {
        gesture_controller = new GestureController (CUSTOM) {
            progress = 1
        };
        add_gesture_controller (gesture_controller);

        window.size_changed.connect (update_target);
        window.shown.connect (update_target);

        manager.notify["visible"].connect (sync_visible);
        sync_visible ();
    }

    private void update_target () {
        var actor = (Clutter.Actor) window.get_compositor_private ();
        hide_target = new PropertyTarget (CUSTOM, actor, "translation-y", typeof (float), 0f, actor.height);
    }

    private void sync_visible () {
        if (manager.visible) {
            gesture_controller.goto (0);
        } else {
            gesture_controller.goto (1);
        }
    }

    protected override double get_hidden_progress () {
        return gesture_controller.progress;
    }

    protected override void get_window_position (Mtk.Rectangle window_rect, out int x, out int y) {
        var monitor_geom = window.display.get_monitor_geometry (manager.monitor);
        x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;
        y = monitor_geom.y + monitor_geom.height - window_rect.height;
    }
}
