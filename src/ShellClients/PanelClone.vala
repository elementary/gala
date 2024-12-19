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

    private SafeWindowClone clone;
    private Meta.WindowActor actor;

    private GestureTracker default_gesture_tracker;
    private GestureTracker? last_gesture_tracker;
    private bool force_hide = false;

    private HideTracker? hide_tracker;

    public PanelClone (WindowManager wm, PanelWindow panel) {
        Object (wm: wm, panel: panel);
    }

    construct {
        default_gesture_tracker = new GestureTracker (ANIMATION_DURATION, ANIMATION_DURATION);

        clone = new SafeWindowClone (panel.window, true);
        wm.ui_group.add_child (clone);

        actor = (Meta.WindowActor) panel.window.get_compositor_private ();
        // WindowActor position and Window position aren't necessarily the same.
        // The clone needs the actor position
        actor.notify["x"].connect (update_clone_position);
        actor.notify["y"].connect (update_clone_position);
        // Actor visibility might be changed by something else e.g. workspace switch
        // but we want to keep it in sync with us
        actor.notify["visible"].connect (update_visible);

        notify["panel-hidden"].connect (() => {
            update_visible ();
            // When hidden changes schedule an update to make sure it's actually
            // correct since things might have changed during the animation
            if (hide_tracker != null) {
                hide_tracker.schedule_update ();
            }
        });

        // Make sure the actor is visible once it's focused FIXME: better event not only focused
        // https://github.com/elementary/gala/issues/2080
        panel.window.focused.connect (update_visible);

        update_visible ();
        update_clone_position ();

        Idle.add_once (() => {
            if (hide_mode == NEVER) {
                show (default_gesture_tracker, false);
            } else {
                hide_tracker.schedule_update ();
            }
        });
    }

    private void update_visible () {
        actor.visible = !panel_hidden;

        if (actor.visible && !wm.get_display ().get_monitor_in_fullscreen (panel.window.get_monitor ())) {
            // The actor has just been revealed, make sure it's at the top
            // https://github.com/elementary/gala/issues/2080
            actor.get_parent ().set_child_above_sibling (actor, null);
        }
    }

    private void update_clone_position () {
        clone.set_position (calculate_clone_x (panel_hidden), calculate_clone_y (panel_hidden));
    }

    private float calculate_clone_x (bool hidden) {
        switch (panel.anchor) {
            case TOP:
            case BOTTOM:
                return actor.x;
            default:
                return 0;
        }
    }

    private float calculate_clone_y (bool hidden) {
        switch (panel.anchor) {
            case TOP:
                return hidden ? actor.y - actor.height : actor.y;
            case BOTTOM:
                return hidden ? actor.y + actor.height : actor.y;
            default:
                return 0;
        }
    }

    private void hide (GestureTracker gesture_tracker, bool with_gesture) {
        if (panel_hidden || last_gesture_tracker != null && last_gesture_tracker.recognizing) {
            return;
        }

        last_gesture_tracker = gesture_tracker;

        panel_hidden = true;

        if (!Meta.Util.is_wayland_compositor ()) {
            Utils.x11_set_window_pass_through (panel.window);
        }

        if (panel.anchor != TOP && panel.anchor != BOTTOM) {
            warning ("Animated hide not supported for side yet.");
            return;
        }

        clone.visible = true;

        new GesturePropertyTransition (clone, gesture_tracker, "y", null, calculate_clone_y (true)).start (with_gesture);
    }

    private void show (GestureTracker gesture_tracker, bool with_gesture) {
        if (!panel_hidden || force_hide || last_gesture_tracker != null && last_gesture_tracker.recognizing) {
            return;
        }

        last_gesture_tracker = gesture_tracker;

        if (!Meta.Util.is_wayland_compositor ()) {
            Utils.x11_unset_window_pass_through (panel.window);
        }

        new GesturePropertyTransition (clone, gesture_tracker, "y", null, calculate_clone_y (false)).start (with_gesture, (completions) => {
            if (completions > 0) {
                clone.visible = false;
                panel_hidden = false;
            }
        });
    }

    public void set_force_hide (bool force_hide, GestureTracker gesture_tracker, bool with_gesture) {
        this.force_hide = force_hide;

        if (force_hide) {
            hide (gesture_tracker, with_gesture);
        } else if (hide_mode == NEVER) {
            show (gesture_tracker, with_gesture);
        } else {
            hide_tracker.update_overlap (gesture_tracker, with_gesture);
        }
    }
}
