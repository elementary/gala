/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellWindow : PositionedWindow {
    [Flags]
    public enum State {
        CUSTOM_HIDDEN,
        MULTITASKING_VIEW,
        DESKTOP
    }

    private const State HIDING_STATES = CUSTOM_HIDDEN | MULTITASKING_VIEW;

    private Meta.WindowActor actor;
    private State current_state = DESKTOP;

    private bool gesture_ongoing = false;

    public ShellWindow (Meta.Window window, Position position, Variant? position_data = null) {
        base (window, position, position_data);
    }

    construct {
        actor = (Meta.WindowActor) window.get_compositor_private ();
    }

    public void add_state (State state, GestureTracker gesture_tracker, bool with_gesture) {
        animate (current_state | state, gesture_tracker, with_gesture);
    }

    public void remove_state (State state, GestureTracker gesture_tracker, bool with_gesture) {
        animate (current_state & ~state, gesture_tracker, with_gesture);
    }

    private void animate (State new_state, GestureTracker gesture_tracker, bool with_gesture) {
        if (new_state == current_state || gesture_ongoing) {
            return;
        }

        gesture_ongoing = true;

        InternalUtils.update_transients_visible (window, false);

        new GesturePropertyTransition (
            actor, gesture_tracker, get_animation_property (), null, calculate_value ((new_state & HIDING_STATES) != 0)
        ).start (with_gesture, () => InternalUtils.update_transients_visible (window, (current_state & HIDING_STATES) == 0));

        gesture_tracker.add_end_callback (with_gesture, (percentage, completions) => {
            if (completions != 0) {
                current_state = new_state;
            }

            if (!Meta.Util.is_wayland_compositor ()) {
                if ((current_state & HIDING_STATES) != 0) {
                    Utils.x11_set_window_pass_through (window);
                } else {
                    Utils.x11_unset_window_pass_through (window);
                }
            }

            gesture_ongoing = false;
        });
    }

    private string get_animation_property () {
        switch (position) {
            case TOP:
            case BOTTOM:
                return "translation-y";
            default:
                return "opacity";
        }
    }

    private Value calculate_value (bool hidden) {
        switch (position) {
            case TOP:
                return hidden ? -actor.height : 0f;
            case BOTTOM:
                return hidden ? actor.height : 0f;
            default:
                return hidden ? 0u : 255u;
        }
    }
}
