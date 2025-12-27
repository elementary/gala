/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

private class Gala.TouchpadBackend : Object, GestureBackend {
    private const int TOUCHPAD_BASE_HEIGHT = 300;
    private const int TOUCHPAD_BASE_WIDTH = 400;
    private const int DRAG_THRESHOLD_DISTANCE = 16;

    private enum State {
        NONE,
        IGNORED,
        IGNORED_HORIZONTAL,
        IGNORED_VERTICAL,
        ONGOING
    }

    public Clutter.Actor actor { get; construct; }
    public GestureController.Group group { get; construct; }

    private static List<TouchpadBackend> instances = new List<TouchpadBackend> ();

    private State state = NONE;
    private GestureDirection direction = UNKNOWN;
    private double distance_x = 0;
    private double distance_y = 0;
    private double distance = 0;

    public TouchpadBackend (Clutter.Actor actor, GestureController.Group group) {
        Object (actor: actor, group: group);
    }

    ~TouchpadBackend () {
        instances.remove (this);
    }

    construct {
        actor.captured_event.connect (on_captured_event);

        instances.append (this);
    }

    public override void cancel_gesture () {
        state = IGNORED;
    }

    private bool on_captured_event (Clutter.Event event) {
        return handle_event (event, true);
    }

    private bool handle_event (Clutter.Event event, bool main_handler) {
        if (event.get_type () != TOUCHPAD_SWIPE) {
            return Clutter.EVENT_PROPAGATE;
        }

        if (state != ONGOING && (event.get_gesture_phase () == END || event.get_gesture_phase () == CANCEL)) {
            reset ();
            return Clutter.EVENT_PROPAGATE;
        }

        if (state == IGNORED) {
            return Clutter.EVENT_PROPAGATE;
        }

        double delta_x, delta_y;
        event.get_gesture_motion_delta_unaccelerated (out delta_x, out delta_y);

        if (state != ONGOING) {
            distance_x += delta_x;
            distance_y += delta_y;

            Gesture? gesture = null;
            State state_if_ignored = NONE;

            var threshold = main_handler ? DRAG_THRESHOLD_DISTANCE : DRAG_THRESHOLD_DISTANCE * 4;

            if (state != IGNORED_HORIZONTAL && distance_x.abs () >= threshold) {
                gesture = new Gesture ();
                gesture.direction = direction = distance_x > 0 ? GestureDirection.RIGHT : GestureDirection.LEFT;
                state_if_ignored = IGNORED_HORIZONTAL;
            } else if (state != IGNORED_VERTICAL && distance_y.abs () >= threshold) {
                gesture = new Gesture ();
                gesture.direction = direction = distance_y > 0 ? GestureDirection.DOWN : GestureDirection.UP;
                state_if_ignored = IGNORED_VERTICAL;
            } else {
                return Clutter.EVENT_PROPAGATE;
            }

            gesture.type = event.get_type ();
            gesture.fingers = (int) event.get_touchpad_gesture_finger_count ();
            gesture.performed_on_device_type = event.get_source_device ().get_device_type ();

            if (!on_gesture_detected (gesture, event.get_time ())) {
                if (state == NONE) {
                    state = state_if_ignored;
                } else { // Both directions were ignored, so stop trying
                    state = IGNORED;
                }
                return Clutter.EVENT_PROPAGATE;
            }

            state = ONGOING;
            on_begin (0, event.get_time ());
        } else if (main_handler && group != NONE) {
            foreach (var instance in instances) {
                if (instance != this && instance.group == group) {
                    instance.handle_event (event, false);
                }
            }
        }

        distance += get_value_for_direction (delta_x, delta_y);

        var percentage = get_percentage (distance);

        switch (event.get_gesture_phase ()) {
            case BEGIN:
                // We don't rely on the begin phase because we delay activation until the drag threshold is reached
                break;

            case UPDATE:
                on_update (percentage, event.get_time ());
                break;

            case END:
            case CANCEL:
                on_end (percentage, event.get_time ());
                reset ();
                break;
        }

        return Clutter.EVENT_STOP;
    }

    private void reset () {
        state = NONE;
        distance = 0;
        direction = UNKNOWN;
        distance_x = 0;
        distance_y = 0;
    }

    private double get_percentage (double value) {
        return value / (direction == LEFT || direction == RIGHT ? TOUCHPAD_BASE_WIDTH : TOUCHPAD_BASE_HEIGHT);
    }

    private double get_value_for_direction (double delta_x, double delta_y) {
        if (direction == LEFT || direction == RIGHT) {
            return direction == LEFT ? -delta_x : delta_x;
        } else {
            return direction == UP ? -delta_y : delta_y;
        }
    }
}
