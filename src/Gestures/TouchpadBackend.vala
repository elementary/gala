/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.TouchpadBackend : Object, GestureBackend {
    private const int TOUCHPAD_BASE_HEIGHT = 300;
    private const int TOUCHPAD_BASE_WIDTH = 400;
    private const int DRAG_THRESHOLD_DISTANCE = 16;

    private enum State {
        NONE,
        IGNORED,
        ONGOING
    }

    public Clutter.Actor actor { get; construct; }

    private State state = NONE;
    private GestureDirection direction = UNKNOWN;
    private double distance_x = 0;
    private double distance_y = 0;
    private double distance = 0;

    public TouchpadBackend (Clutter.Actor actor) {
        Object (actor: actor);
    }

    construct {
        actor.captured_event.connect (on_captured_event);
    }

    private bool on_captured_event (Clutter.Event event) {
        if (event.get_type () != TOUCHPAD_SWIPE) {
            return Clutter.EVENT_PROPAGATE;
        }

        if (state == IGNORED) {
            if (event.get_gesture_phase () == END || event.get_gesture_phase () == CANCEL) {
                reset ();
            }

            return Clutter.EVENT_PROPAGATE;
        }

        double delta_x, delta_y;
        event.get_gesture_motion_delta_unaccelerated (out delta_x, out delta_y);

        if (state == NONE) {
            distance_x += delta_x;
            distance_y += delta_y;

            var distance = Math.sqrt (distance_x * distance_x + distance_y * distance_y);

            if (distance >= DRAG_THRESHOLD_DISTANCE) {
                var gesture = new Gesture ();
                gesture.type = event.get_type ();
                gesture.fingers = (int) event.get_touchpad_gesture_finger_count ();
                gesture.performed_on_device_type = event.get_device ().get_device_type ();
                direction = gesture.direction = get_direction (distance_x, distance_y);

                if (!on_gesture_detected (gesture, event.get_time ())) {
                    state = IGNORED;
                    return Clutter.EVENT_PROPAGATE;
                }

                state = ONGOING;
            } else {
                return Clutter.EVENT_PROPAGATE;
            }
        }

        distance += get_value_for_direction (delta_x, delta_y);

        var percentage = get_percentage (distance);

        switch (event.get_gesture_phase ()) {
            case BEGIN:
                on_begin (distance, event.get_time ());
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

    private GestureDirection get_direction (double delta_x, double delta_y) {
        if (delta_x.abs () > delta_y.abs ()) {
            return delta_x > 0 ? GestureDirection.RIGHT : GestureDirection.LEFT;
        } else {
            return delta_y > 0 ? GestureDirection.DOWN : GestureDirection.UP;
        }
    }
}
