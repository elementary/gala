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
    private State pending_state = DESKTOP;
    private State current_state = DESKTOP;

    private bool gesture_ongoing = false;

    public ShellWindow (Meta.Window window, Position position, Variant? position_data = null) {
        base (window, position, position_data);
    }

    construct {
        actor = (Meta.WindowActor) window.get_compositor_private ();
    }

    public void add_state (State state, GestureTracker gesture_tracker) {
        pending_state |= state;
        animate (pending_state, gesture_tracker);
    }

    public void remove_state (State state, GestureTracker gesture_tracker) {
        pending_state &= ~state;
        animate (pending_state, gesture_tracker);
    }

    private void animate (State new_state, GestureTracker gesture_tracker) {
        if (new_state == current_state || gesture_ongoing) {
            return;
        }

        gesture_ongoing = true;

        update_visibility (true);

        new GesturePropertyTransition (
            actor, gesture_tracker, get_animation_property (), null, calculate_value ((new_state & HIDING_STATES) != 0)
        ).start (() => update_visibility (false));

        gesture_tracker.add_end_callback ((percentage, completions) => {
            gesture_ongoing = false;

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

            if (pending_state != new_state) { // We have received new state while animating
                animate (pending_state, gesture_tracker);
            } else {
                pending_state = current_state;
            }
        });
    }

    private void update_visibility (bool animating) {
        var visible = (current_state & HIDING_STATES) == 0;

        actor.visible = animating || visible;

        unowned var manager = ShellClientsManager.get_instance ();
        window.foreach_transient ((transient) => {
            if (manager.is_itself_positioned (transient)) {
                return true;
            }

            unowned var actor = (Meta.WindowActor) transient.get_compositor_private ();

            actor.visible = visible && !animating;

            return true;
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
