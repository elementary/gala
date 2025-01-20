/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellWindow : WindowPositioner {
    [Flags]
    public enum State {
        CUSTOM_HIDDEN,
        DESKTOP,
        MULTITASKING_VIEW
    }

    private Meta.WindowActor actor;

    private State state = DESKTOP;
    private bool hidden = false;

    private bool gesture_ongoing = false;

    public ShellWindow (Meta.Window window, Position position, Variant? position_data = null) {
        base (window.display, window, position, position_data);
    }

    construct {
        actor = (Meta.WindowActor) window.get_compositor_private ();
    }

    public void add_state (State state, GestureTracker gesture_tracker) {
        this.state |= state;
        check_hide (gesture_tracker);
    }

    public void remove_state (State state, GestureTracker gesture_tracker) {
        this.state &= ~state;
        check_hide (gesture_tracker);
    }

    private void check_hide (GestureTracker gesture_tracker) {
        if (gesture_ongoing) {
            return;
        }

        if (CUSTOM_HIDDEN in state) {
            animate (true, gesture_tracker);
            return;
        }

        if (MULTITASKING_VIEW in state) {
            animate (true, gesture_tracker);
            return;
        }

        animate (false, gesture_tracker);
    }

    private void animate (bool hide, GestureTracker gesture_tracker) {
        if (hide == hidden) {
            return;
        }

        gesture_ongoing = true;

        if (!Meta.Util.is_wayland_compositor ()) {
            Utils.x11_set_window_pass_through (window);
        }

        InternalUtils.update_transients_visible (window, false);

        new GesturePropertyTransition (
            actor, gesture_tracker, get_animation_property (), null, calculate_value (hide)
        ).start (true, () => InternalUtils.update_transients_visible (window, !hidden));

        gesture_tracker.add_success_callback (false, () => {
            hidden = hide;
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
