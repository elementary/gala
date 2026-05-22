/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.OSKWindow : ShellWindow, RootTarget {
    public InputMethod im { private get; construct; }

    public Clutter.Actor? actor { get { return (Clutter.Actor) window.get_compositor_private (); } }

    private GestureController gesture_controller;

    private OSKFocusTracker focus_tracker;
    private Meta.Window? focus_window;

    public OSKWindow (InputMethod im, Meta.Window window) {
        Object (im: im, window: window);
    }

    construct {
        gesture_controller = new GestureController (CUSTOM) {
            progress = 1
        };
        add_gesture_controller (gesture_controller);

        window.size_changed.connect (update_target);
        window.shown.connect (update_target);

        im.notify["input-panel-active"].connect (sync_visible);
        window.shown.connect (sync_visible);

        focus_tracker = new OSKFocusTracker (window.get_display (), im);
        focus_tracker.notify["current-monitor"].connect (position_window);
        focus_tracker.notify["current-focus-window"].connect (update_focus_window);
        update_focus_window ();

        im.notify["cursor-location"].connect (update_focus_window_offset);
    }

    private void update_target () {
        var actor = (Clutter.Actor) window.get_compositor_private ();
        hide_target = new PropertyTarget (CUSTOM, actor, "translation-y", typeof (float), 0f, actor.height);
    }

    private void sync_visible () {
        if (im.input_panel_active) {
            gesture_controller.goto (0);
        } else {
            gesture_controller.goto (1);
        }
    }

    private void update_focus_window () {
        if (focus_window == focus_tracker.current_focus_window) {
            return;
        }

        if (focus_window != null) {
            /* If a grab op is ongoing while the focus window changed we assume the window
               was grabbed so update the offset without animation to avoid flickering */
            update_window_offset (focus_window, 0, !window.get_display ().is_grabbed ());
        }

        focus_window = focus_tracker.current_focus_window;

        update_focus_window_offset ();
    }

    private void update_focus_window_offset () {
        if (focus_window == null) {
            return;
        }

        var offset = calculate_window_offset (im.cursor_location);
        update_window_offset (focus_window, offset);
    }

    private float calculate_window_offset (Graphene.Rect cursor_rect) {
        var keyboard_rect = window.get_frame_rect ();

        if (cursor_rect.get_y () + cursor_rect.get_height () > keyboard_rect.y) {
            return (float) (keyboard_rect.y - (cursor_rect.get_y () + cursor_rect.get_height ()));
        }

        return 0f;
    }

    private void update_window_offset (Meta.Window window, float translation, bool animate = true) {
        var window_actor = (Meta.WindowActor) window.get_compositor_private ();

        if (!animate) {
            window_actor.remove_all_transitions ();
            window_actor.translation_y = translation;
            return;
        }

        window_actor.save_easing_state ();
        window_actor.set_easing_duration (200);
        window_actor.set_easing_mode (EASE);
        window_actor.translation_y = translation;
        window_actor.restore_easing_state ();
    }

    protected override double get_hidden_progress () {
        return gesture_controller.progress;
    }

    protected override void get_window_position (Mtk.Rectangle window_rect, out int x, out int y) {
        var monitor_geom = window.display.get_monitor_geometry (focus_tracker.current_monitor);
        x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;
        y = monitor_geom.y + monitor_geom.height - window_rect.height;
    }
}
