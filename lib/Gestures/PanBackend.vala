/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

internal class Gala.PanBackend : Object, GestureBackend {
    public WindowManager wm { get; construct; }
    public Clutter.Actor actor { get; construct; }

    private ModalProxy? modal_proxy;

    private Clutter.PanAxis pan_axis;
    private Clutter.PanAction pan_action;

    private GestureDirection direction;

    private float origin_x;
    private float origin_y;

    private float current_x;
    private float current_y;

    private float last_x_coord;
    private float last_y_coord;
    private uint last_n_points;

    public PanBackend (WindowManager wm, Clutter.Actor actor) {
        Object (wm: wm, actor: actor);
    }

    construct {
        pan_action = new Clutter.PanAction () {
            n_touch_points = 1
        };

        actor.add_action_full ("pan-gesture", CAPTURE, pan_action);

        pan_action.gesture_begin.connect (on_gesture_begin);
        pan_action.pan.connect (on_pan);
        pan_action.gesture_end.connect (on_gesture_end);
        pan_action.gesture_cancel.connect (on_gesture_end);
    }

    ~PanBackend () {
        actor.remove_action (pan_action);
    }

    private bool on_gesture_begin () {
        if (pan_action.get_last_event (0).get_source_device ().get_device_type () != TOUCHSCREEN_DEVICE) {
            return false;
        }

        float x_coord, y_coord;
        pan_action.get_press_coords (0, out x_coord, out y_coord);

        origin_x = current_x = x_coord;
        origin_y = current_y = y_coord;

        var time = pan_action.get_last_event (0).get_time ();

        var handled = on_gesture_detected (build_gesture (), time);

        if (!handled) {
            reset ();
            return false;
        }

        modal_proxy = wm.push_modal (actor, true);

        on_begin (0, time);

        return true;
    }

    private void on_gesture_end () {
        if (modal_proxy != null) {
            // Only emit on end if we actually began the gesture
            on_end (calculate_percentage (), Meta.CURRENT_TIME);
        }

        reset ();
    }

    private void reset () {
        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
            modal_proxy = null;
        }

        direction = GestureDirection.UNKNOWN;
        last_n_points = 0;
        last_x_coord = 0;
        last_y_coord = 0;
    }

    private bool on_pan (Clutter.PanAction pan_action, Clutter.Actor actor, bool interpolate) {
        var time = pan_action.get_last_event (0).get_time ();

        float x, y;
        pan_action.get_motion_coords (0, out x, out y);

        if (pan_action.get_n_current_points () == last_n_points) {
            current_x += x - last_x_coord;
            current_y += y - last_y_coord;
        }

        last_x_coord = x;
        last_y_coord = y;
        last_n_points = pan_action.get_n_current_points ();

        on_update (calculate_percentage (), time);

        return true;
    }

    private double calculate_percentage () {
        float current, origin;
        if (pan_axis == X_AXIS) {
            current = direction == RIGHT ? float.max (current_x, origin_x) : float.min (current_x, origin_x);
            origin = origin_x;
        } else {
            current = direction == DOWN ? float.max (current_y, origin_y) : float.min (current_y, origin_y);
            origin = origin_y;
        }

        return (current - origin).abs () / request_travel_distance ();
    }

    private Gesture build_gesture () {
        float delta_x, delta_y;
        ((Clutter.GestureAction) pan_action).get_motion_delta (0, out delta_x, out delta_y);

        pan_axis = delta_x.abs () > delta_y.abs () ? Clutter.PanAxis.X_AXIS : Clutter.PanAxis.Y_AXIS;

        if (pan_axis == X_AXIS) {
            direction = delta_x > 0 ? GestureDirection.RIGHT : GestureDirection.LEFT;
        } else {
            direction = delta_y > 0 ? GestureDirection.DOWN : GestureDirection.UP;
        }

        return new Gesture () {
            type = Clutter.EventType.TOUCHPAD_SWIPE,
            direction = direction,
            fingers = (int) pan_action.get_n_current_points (),
            performed_on_device_type = Clutter.InputDeviceType.TOUCHSCREEN_DEVICE,
            origin_x = origin_x,
            origin_y = origin_y
        };
    }
}
