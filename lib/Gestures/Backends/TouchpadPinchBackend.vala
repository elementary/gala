/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

private class Gala.TouchpadPinchBackend : Object, GestureBackend {
    private enum State {
        NONE,
        IGNORED,
        ONGOING
    }

    public Clutter.Actor actor { get; construct; }

    private State state = NONE;
    private double percentage = 0.0;

    public TouchpadPinchBackend (Clutter.Actor actor) {
        Object (actor: actor);
    }

    construct {
        actor.captured_event.connect (handle_event);
    }

    public override void cancel_gesture () {
        state = IGNORED;
    }

    private bool handle_event (Clutter.Event event) {
        if (event.get_type () != TOUCHPAD_PINCH) {
            return Clutter.EVENT_PROPAGATE;
        }

        if (state != ONGOING && (event.get_gesture_phase () == END || event.get_gesture_phase () == CANCEL)) {
            reset ();
            return Clutter.EVENT_PROPAGATE;
        }

        if (state == IGNORED) {
            return Clutter.EVENT_PROPAGATE;
        }

        if (state == NONE && event.get_gesture_phase () != BEGIN) {
            /* We never got a begin phase so something else initially handled the gesture
               but disappeared. Don't start handling it now. Will probably never happen */
            return Clutter.EVENT_PROPAGATE;
        }

        if (state != ONGOING) {
            var gesture = new Gesture ();
            gesture.direction = OUT;
            gesture.type = event.get_type ();
            gesture.fingers = (int) event.get_touchpad_gesture_finger_count ();
            gesture.performed_on_device_type = event.get_source_device ().get_device_type ();

            if (!on_gesture_detected (gesture, event.get_time ())) {
                state = IGNORED;
                return Clutter.EVENT_PROPAGATE;
            }

            state = ONGOING;
        }

        if (event.get_gesture_phase () == UPDATE) {
            /* When the gesture ends the pinch scale is already reset */
            percentage = event.get_gesture_pinch_scale () - 1.0;
        }

        switch (event.get_gesture_phase ()) {
            case BEGIN:
                on_begin (0, event.get_time ());
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
        percentage = 0.0;
    }
}
