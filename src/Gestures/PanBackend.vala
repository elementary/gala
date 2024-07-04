public class Gala.PanBackend : Object {
    public signal void on_gesture_detected (Gesture gesture);
    public signal void on_begin (double delta, uint64 time);
    public signal void on_update (double delta, uint64 time);
    public signal void on_end (double delta, uint64 time);

    public Clutter.Actor actor { get; construct; }
    public GestureSettings settings { get; construct; }

    private Clutter.PanAxis pan_axis;
    private Clutter.PanAction pan_action;

    private bool started;
    private GestureDirection direction;

    private double start_val_x;
    private double start_val_y;

    public PanBackend (Clutter.Actor actor) {
        Object (actor: actor);
    }

    construct {
        pan_action = new Clutter.PanAction () {
            n_touch_points = 3
        };

        actor.add_action_full ("pan-gesture", CAPTURE, pan_action);

        pan_action.gesture_begin.connect (on_gesture_begin);
        pan_action.pan.connect (on_pan);
        pan_action.gesture_end.connect (on_gesture_end);
    }

    private bool on_gesture_begin () {
        float x_coord, y_coord;
        pan_action.get_press_coords (0, out x_coord, out y_coord);

        start_val_x = x_coord;
        start_val_y = y_coord;

        return true;
    }

    private void on_gesture_end () {
        started = false;
        direction = GestureDirection.UNKNOWN;

        float x_coord, y_coord;
        pan_action.get_motion_coords (0, out x_coord, out y_coord);
        on_end (calculate_percentage (x_coord, y_coord), pan_action.get_last_event (0).get_time ());
    }

    private bool on_pan (Clutter.PanAction pan_action, Clutter.Actor actor, bool interpolate) {
        if (pan_action != pan_action) {
            return false;
        }

        uint64 time = pan_action.get_last_event (0).get_time ();

        float x_coord, y_coord;
        pan_action.get_motion_coords (0, out x_coord, out y_coord);

        if (!started) {
            started = true;
            Gesture gesture = build_gesture (x_coord, y_coord);
            on_gesture_detected (gesture);

            on_begin (calculate_percentage (x_coord, y_coord), time);
        } else {
            on_update (calculate_percentage (x_coord, y_coord), time);
        }

        return true;
    }

    private double calculate_percentage (double current_val_x, double current_val_y) {
        double current_val, start_val;
        if (pan_axis == X_AXIS) {
            current_val = current_val_x;
            start_val = start_val_x;
        } else {
            current_val = current_val_y;
            start_val = start_val_y;
        }

        return (current_val - start_val).abs () / actor.get_width ();
    }

    private Gesture build_gesture (double coord_x, double coord_y) {
        pan_axis = (coord_x - start_val_x).abs () > (coord_y - start_val_y).abs () ? Clutter.PanAxis.X_AXIS : Clutter.PanAxis.Y_AXIS;

        if (pan_axis == X_AXIS) {
            direction = coord_x - start_val_x > 0 ? GestureDirection.RIGHT : GestureDirection.LEFT;
        } else {
            direction = coord_y - start_val_y > 0? GestureDirection.DOWN : GestureDirection.UP;
        }

        warning ("X: %s, START X: %s", coord_x.to_string (), start_val_x.to_string ());

        warning ("DETECTED GESTURE %s", pan_axis.to_string ());

        return new Gesture () {
            type = Clutter.EventType.TOUCHPAD_SWIPE,
            direction = direction,
            fingers = (int) pan_action.get_n_current_points (),
            performed_on_device_type = Clutter.InputDeviceType.TOUCHPAD_DEVICE
        };
    }
}
