/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PanelClone : Object {
    public const int ANIMATION_DURATION = 250;

    public WindowManager wm { get; construct; }
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

    public SafeWindowClone clone;
    private Meta.WindowActor actor;

    private HideTracker? hide_tracker;

    public PanelClone (WindowManager wm, PanelWindow panel) {
        Object (wm: wm, panel: panel);
    }

    construct {
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

        update_visible ();
        update_clone_position ();

        Idle.add_once (() => {
            if (hide_mode == NEVER) {
                show ();
            } else {
                hide_tracker.schedule_update ();
            }
        });
    }

    private void update_visible () {
        actor.visible = !panel_hidden;
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

    private int get_animation_duration () {
        var fullscreen = wm.get_display ().get_monitor_in_fullscreen (panel.window.get_monitor ());
        var should_animate = wm.enable_animations && !wm.workspace_view.is_opened () && !fullscreen;
        return should_animate ? ANIMATION_DURATION : 0;
    }

    private void hide () {
        if (panel_hidden || animating) {
            return;
        }

        animating = true;

        panel_hidden = true;

        if (panel.anchor != TOP && panel.anchor != BOTTOM) {
            warning ("Animated hide not supported for side yet.");
            return;
        }

        clone.visible = true;

        clone.save_easing_state ();
        clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        clone.set_easing_duration (get_animation_duration ());
        clone.y = calculate_clone_y (true);
        clone.restore_easing_state ();

        animating = false;
    }

    private bool animating = false;
    public void show (GestureTracker? with_gesture_tracker = null) {
        if (!panel_hidden || animating) {
            return;
        }

        animating = true;

        var initial_y = clone.y;
        var target_y = calculate_clone_y (false);

        GestureTracker.OnUpdate on_update = (percentage) => {
            var value = GestureTracker.animation_value (initial_y, target_y, percentage, true);
            clone.y = value;
        };

        GestureTracker.OnEnd on_end = (percentage, cancel_action, calculated_duration) => {
            if (cancel_action) {
                animating = false;
                hide ();
                return;
            }

            clone.save_easing_state ();
            clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            clone.set_easing_duration (calculated_duration);
            clone.y = calculate_clone_y (false);
            clone.restore_easing_state ();

            Timeout.add (calculated_duration, () => {
                clone.visible = false;
                panel_hidden = false;
                animating = false;
                return Source.REMOVE;
            });
        };

        if (with_gesture_tracker != null) {
            with_gesture_tracker.connect_handlers (null, (owned) on_update, (owned) on_end);
        } else {
            on_end (1, false, get_animation_duration ());
        }
    }
}
