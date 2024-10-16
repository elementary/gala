public class Gala.PanBackend : Object {
    public signal bool on_gesture_detected (Gesture gesture);
    public signal void on_begin (double delta, uint64 time);
    public signal void on_update (double delta, uint64 time);
    public signal void on_end (double delta, uint64 time);

    public Clutter.Actor actor { get; construct; }
    public GestureSettings settings { get; construct; }

    private Clutter.PanAxis pan_axis;
    private Clutter.PanAction pan_action;

    private GestureDirection direction;

    private float origin_x;
    private float origin_y;

    public PanBackend (Clutter.Actor actor) {
        Object (actor: actor);
    }

    construct {
        pan_action = new Clutter.PanAction () {
            n_touch_points = 1
        };

        actor.add_action_full ("pan-gesture", CAPTURE, pan_action);

        pan_action.gesture_begin.connect (on_gesture_begin);
        pan_action.pan.connect (on_pan);
        pan_action.gesture_end.connect (on_gesture_end);
    }

    private bool on_gesture_begin () {
        float x_coord, y_coord;
        pan_action.get_press_coords (0, out x_coord, out y_coord);

        origin_x = x_coord;
        origin_y = y_coord;

        var handled = on_gesture_detected (build_gesture ());

        if (!handled) {
            return false;
        }

        on_begin (0, pan_action.get_last_event (0).get_time ());

        return true;
    }

    private void on_gesture_end () {
        direction = GestureDirection.UNKNOWN;

        float x_coord, y_coord;
        pan_action.get_motion_coords (0, out x_coord, out y_coord);
        on_end (calculate_percentage (x_coord, y_coord), pan_action.get_last_event (0).get_time ());
    }

    private bool on_pan (Clutter.PanAction pan_action, Clutter.Actor actor, bool interpolate) {
        uint64 time = pan_action.get_last_event (0).get_time ();

        float x_coord, y_coord;
        pan_action.get_motion_coords (0, out x_coord, out y_coord);

        on_update (calculate_percentage (x_coord, y_coord), time);

        return true;
    }

    private double calculate_percentage (float current_x, float current_y) {
        float current, origin;
        if (pan_axis == X_AXIS) {
            current = current_x;
            origin = origin_x;
        } else {
            current = current_y;
            origin = origin_y;
        }

        return (current - origin).abs () / actor.get_width ();
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
            performed_on_device_type = Clutter.InputDeviceType.TOUCHPAD_DEVICE,
            origin_x = origin_x,
            origin_y = origin_y
        };
    }
}
