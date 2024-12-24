/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PanelClone : Object {
    private const int ANIMATION_DURATION = 250;

    public WindowManager wm { get; construct; }
    public unowned PanelWindow panel { get; construct; }

    public Pantheon.Desktop.HideMode hide_mode {
        get {
            return hide_tracker == null ? Pantheon.Desktop.HideMode.NEVER : hide_tracker.hide_mode;
        }
        set {
            if (value == NEVER) {
                hide_tracker = null;
                show (default_gesture_tracker, false);
                return;
            } else if (hide_tracker == null) {
                hide_tracker = new HideTracker (wm.get_display (), panel, default_gesture_tracker);
                hide_tracker.hide.connect (hide);
                hide_tracker.show.connect (show);
            }

            hide_tracker.hide_mode = value;
        }
    }

    public bool panel_hidden { get; private set; default = true; }

    private Meta.WindowActor actor;

    private GestureTracker default_gesture_tracker;
    private GestureTracker last_gesture_tracker;

    private HideTracker? hide_tracker;

    public PanelClone (WindowManager wm, PanelWindow panel) {
        Object (wm: wm, panel: panel);
    }

    construct {
        last_gesture_tracker = default_gesture_tracker = new GestureTracker (ANIMATION_DURATION, ANIMATION_DURATION);

        actor = (Meta.WindowActor) panel.window.get_compositor_private ();

        notify["panel-hidden"].connect (() => {
            // When hidden changes schedule an update to make sure it's actually
            // correct since things might have changed during the animation
            if (hide_tracker != null) {
                hide_tracker.schedule_update ();
            }
        });

        Idle.add_once (() => {
            if (hide_mode == NEVER) {
                show (default_gesture_tracker, false);
            } else {
                hide_tracker.schedule_update ();
            }
        });
    }

    private float calculate_y (bool hidden) {
        switch (panel.anchor) {
            case TOP:
                return hidden ? -actor.height : 0;
            case BOTTOM:
                return hidden ? actor.height : 0;
            default:
                return 0;
        }
    }

    private void hide (GestureTracker gesture_tracker, bool with_gesture) {
        if (panel_hidden || last_gesture_tracker.recognizing) {
            return;
        }

        last_gesture_tracker = gesture_tracker;

        if (!Meta.Util.is_wayland_compositor ()) {
            Utils.x11_set_window_pass_through (panel.window);
        }

        if (panel.anchor != TOP && panel.anchor != BOTTOM) {
            warning ("Animated hide not supported for side yet.");
            return;
        }

        new GesturePropertyTransition (actor, gesture_tracker, "translation-y", null, calculate_y (true)).start (with_gesture);

        gesture_tracker.add_success_callback (with_gesture, () => panel_hidden = true);
    }

    private void show (GestureTracker gesture_tracker, bool with_gesture) {
        if (!panel_hidden || last_gesture_tracker.recognizing) {
            return;
        }

        last_gesture_tracker = gesture_tracker;

        if (!Meta.Util.is_wayland_compositor ()) {
            Utils.x11_unset_window_pass_through (panel.window);
        }

        new GesturePropertyTransition (actor, gesture_tracker, "translation-y", null, calculate_y (false)).start (with_gesture);

        gesture_tracker.add_success_callback (with_gesture, () => panel_hidden = false);
    }
}
