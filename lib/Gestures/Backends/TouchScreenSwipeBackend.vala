/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

#if HAS_MUTTER49
private class Gala.TouchScreenSwipeBackend : Object, GestureBackend {
    private const int DRAG_THRESHOLD_DISTANCE = 16;

    public Clutter.Actor actor { get; construct; }

    private Clutter.PanGesture gesture;
    private Clutter.Orientation current_orientation;
    private bool cancelled = false;

    public TouchScreenSwipeBackend (Clutter.Actor actor) {
        Object (actor: actor);
    }

    construct {
        gesture = new Clutter.PanGesture ();
        gesture.may_recognize.connect (on_may_recognize);
        gesture.recognize.connect (on_pan_recognize);
        gesture.pan_update.connect (on_pan_update);
        gesture.end.connect (on_pan_end);
        actor.add_action (gesture);
    }

    ~TouchScreenSwipeBackend () {
        actor.remove_action (gesture);
    }

    public override void cancel_gesture () {
        cancelled = true;
        gesture.cancel ();
    }

    private bool on_may_recognize () {
        var detected_gesture = new Gesture () {
            type = TOUCHPAD_SWIPE,
            direction = get_direction (),
            fingers = (int) gesture.get_n_points (),
            performed_on_device_type = TOUCHSCREEN_DEVICE,
            begin_centroid = gesture.get_begin_centroid ()
        };

        return on_gesture_detected (detected_gesture, Clutter.get_current_event_time ());
    }

    private GestureDirection get_direction () {
        var delta = gesture.get_delta ();
        current_orientation = delta.get_x ().abs () > delta.get_y ().abs () ? Clutter.Orientation.HORIZONTAL : Clutter.Orientation.VERTICAL;
        switch (current_orientation) {
            case HORIZONTAL: return RIGHT;
            case VERTICAL: return DOWN;
            default: return RIGHT;
        }
    }

    private void on_pan_recognize () {
        cancelled = false;

        on_begin (PIXELS, get_used_distance (), Clutter.get_current_event_time ());
    }

    private void on_pan_update () {
        if (cancelled) {
            return;
        }

        on_update (PIXELS, get_used_distance (), Clutter.get_current_event_time ());
    }

    private void on_pan_end () {
        if (cancelled) {
            return;
        }

        on_end (PIXELS, get_used_distance (), Clutter.get_current_event_time ());
    }

    private float get_used_distance () {
        var distance = gesture.get_accumulated_delta ();
        return current_orientation == HORIZONTAL ? distance.get_x () : distance.get_y ();
    }
}
#endif
