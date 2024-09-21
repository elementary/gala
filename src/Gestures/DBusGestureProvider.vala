[DBus (name = "io.elementary.desktop.wm.GestureProvider")]
public class Gala.DBusGestureProvider : Object {
    public signal void on_gesture_detected (Gesture gesture);
    public signal void on_begin (double percentage);
    public signal void on_update (double percentage);
    public signal void on_end (double percentage, bool cancel_action, int calculated_duration);

    private GestureTracker gesture_tracker;

    construct {
        gesture_tracker = new GestureTracker (0, 0);
        gesture_tracker.enable_touchpad ();

        gesture_tracker.on_gesture_detected.connect ((gesture) => on_gesture_detected (gesture));
        gesture_tracker.on_begin.connect ((percentage) => on_begin (percentage));
        gesture_tracker.on_update.connect ((percentage) => on_update (percentage));
        gesture_tracker.on_end.connect ((percentage, cancel_action, calculated_duration) => on_end (percentage, cancel_action, calculated_duration));
    }
}
