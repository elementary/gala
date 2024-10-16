/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PanBackend : Object {
    public delegate float GetTravelDistance ();

    public signal bool on_gesture_detected (Gesture gesture);
    public signal void on_begin (double delta, uint64 time);
    public signal void on_update (double delta, uint64 time);
    public signal void on_end (double delta, uint64 time);

    public Clutter.Actor actor { get; construct; }

    private GetTravelDistance get_travel_distance_func;

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

    private float travel_distance;

    public PanBackend (Clutter.Actor actor, owned GetTravelDistance get_travel_distance_func) {
        Object (actor: actor);

        this.get_travel_distance_func = (owned) get_travel_distance_func;
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
        float x_coord, y_coord;
        pan_action.get_press_coords (0, out x_coord, out y_coord);

        origin_x = current_x = x_coord;
        origin_y = current_y = y_coord;

        var handled = on_gesture_detected (build_gesture ());

        if (!handled) {
            return false;
        }

        travel_distance = get_travel_distance_func ();

        on_begin (0, pan_action.get_last_event (0).get_time ());

        return true;
    }

    private void on_gesture_end () {
        update_coords ();

        on_end (calculate_percentage (), pan_action.get_last_event (0).get_time ());

        direction = GestureDirection.UNKNOWN;
    }

    private bool on_pan (Clutter.PanAction pan_action, Clutter.Actor actor, bool interpolate) {
        uint64 time = pan_action.get_last_event (0).get_time ();

        update_coords ();

        on_update (calculate_percentage (), time);

        return true;
    }

    private void update_coords () {
        float x, y;
        pan_action.get_motion_coords (0, out x, out y);

        if (pan_action.get_n_current_points () == last_n_points) {
            current_x += x - last_x_coord;
            current_y += y - last_y_coord;
        }

        last_x_coord = x;
        last_y_coord = y;
        last_n_points = pan_action.get_n_current_points ();
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

        return (current - origin).abs () / travel_distance;
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
