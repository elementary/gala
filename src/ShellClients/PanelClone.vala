/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PanelClone : Object {
    private const int ANIMATION_DURATION = 250;

    public WindowManagerGala wm { get; construct; }
    public unowned PanelWindow panel { get; construct; }

    public Pantheon.Desktop.HideMode hide_mode {
        get {
            return hide_tracker == null ? Pantheon.Desktop.HideMode.NEVER : hide_tracker.hide_mode;
        }
        set {
            if (value == NEVER) {
                hide_tracker = null;
                show ();
                return;
            } else if (hide_tracker == null) {
                hide_tracker = new HideTracker (wm.get_display (), panel);
                hide_tracker.hide.connect (hide);
                hide_tracker.show.connect (show);
            }

            hide_tracker.hide_mode = value;
        }
    }

    public bool panel_hidden { get; private set; default = true; }

    private Meta.WindowActor actor;

    private GestureTracker default_gesture_tracker;

    private HideTracker? hide_tracker;

    public PanelClone (WindowManagerGala wm, PanelWindow panel) {
        Object (wm: wm, panel: panel);
    }

    construct {
        default_gesture_tracker = new GestureTracker (ANIMATION_DURATION, ANIMATION_DURATION);

        actor = (Meta.WindowActor) panel.window.get_compositor_private ();
        actor.get_parent ().remove_child (actor);
        wm.shell_group.add_child (actor);

        notify["panel-hidden"].connect (() => {
            // When hidden changes schedule an update to make sure it's actually
            // correct since things might have changed during the animation
            if (hide_tracker != null) {
                hide_tracker.schedule_update ();
            }
        });

        wm.get_display ().in_fullscreen_changed.connect (check_hide);

        Idle.add_once (() => {
            if (hide_mode == NEVER) {
                show ();
            } else {
                hide_tracker.schedule_update ();
            }
        });
    }

    private float calculate_translation_y (bool hidden) {
        switch (panel.anchor) {
            case TOP:
                return hidden ? -actor.height : 0;
            case BOTTOM:
                return hidden ? actor.height : 0;
            default:
                return 0;
        }
    }

    private void hide () {
        if (panel_hidden || default_gesture_tracker.recognizing) {
            return;
        }

        if (!Meta.Util.is_wayland_compositor ()) {
            Utils.x11_set_window_pass_through (panel.window);
        }

        if (panel.anchor != TOP && panel.anchor != BOTTOM) {
            warning ("Animated hide not supported for side yet.");
            return;
        }

        InternalUtils.update_transients_visible (panel.window, false);

        new GesturePropertyTransition (
            actor, default_gesture_tracker, "translation-y", null, calculate_translation_y (true)
        ).start (false, () => InternalUtils.update_transients_visible (panel.window, !panel_hidden));

        default_gesture_tracker.add_success_callback (false, () => panel_hidden = true);
    }

    private void show () {
        if (!panel_hidden || default_gesture_tracker.recognizing || wm.get_display ().get_monitor_in_fullscreen (panel.window.get_monitor ())) {
            return;
        }

        if (!Meta.Util.is_wayland_compositor ()) {
            Utils.x11_unset_window_pass_through (panel.window);
        }

        new GesturePropertyTransition (
            actor, default_gesture_tracker, "translation-y", null, calculate_translation_y (false)
        ).start (false, () => InternalUtils.update_transients_visible (panel.window, !panel_hidden));

        default_gesture_tracker.add_success_callback (false, () => panel_hidden = false);
    }

    private void check_hide () {
        if (wm.get_display ().get_monitor_in_fullscreen (panel.window.get_monitor ())) {
            hide ();
        } else if (hide_mode == NEVER) {
            show ();
        } else {
            hide_tracker.update_overlap ();
        }
    }
}
