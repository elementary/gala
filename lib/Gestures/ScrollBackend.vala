/*
 * Copyright 2021-2025 elementary, Inc (https://elementary.io)
 *           2021 José Expósito <jose.exposito89@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * This gesture backend transforms the touchpad scroll events received by an actor into gestures.
 */
private class Gala.ScrollBackend : Object, GestureBackend {
    // Mutter does not expose the size of the touchpad, so we use the same values as GTK apps.
    // From GNOME Shell, TOUCHPAD_BASE_[WIDTH|HEIGHT] / SCROLL_MULTIPLIER
    // https://gitlab.gnome.org/GNOME/gnome-shell/-/blob/master/js/ui/swipeTracker.js
    private const double FINISH_DELTA_HORIZONTAL = 40;
    private const double FINISH_DELTA_VERTICAL = 30;

    public GestureBackend.DeviceType device_type { get { return TOUCHPAD; }}

    public Clutter.Orientation orientation { get; construct; }
    public GestureSettings settings { get; construct; }

    private bool started;
    private double delta_x;
    private double delta_y;
    private GestureDirection direction;

    // When we receive a cancel call, we start ignoring the ongoing scroll until it's over
    private bool ignoring = false;

    construct {
        started = false;
        delta_x = 0;
        delta_y = 0;
        direction = GestureDirection.UNKNOWN;
    }

    public ScrollBackend (Clutter.Actor actor, Clutter.Orientation orientation, GestureSettings settings) {
        Object (orientation: orientation, settings: settings);

        actor.captured_event.connect (on_scroll_event);
        actor.leave_event.connect (on_leave_event);
        // When the actor is turned invisible, we don't receive a scroll finish event which would cause
        // us to ignore the first new scroll event if we're currently ignoring.
        actor.notify["visible"].connect (() => ignoring = false);
    }

    private bool on_scroll_event (Clutter.Event event) {
        if (!can_handle_event (event)) {
            return Clutter.EVENT_PROPAGATE;
        }

        if (ignoring) {
            if (event.get_scroll_finish_flags () != NONE) {
                ignoring = false;
            }
            return Clutter.EVENT_PROPAGATE;
        }

        var time = event.get_time ();
        double x, y;
        event.get_scroll_delta (out x, out y);

        // Scroll events apply the natural scroll preferences out of the box
        // Standardize them so the direction matches the physical direction of the gesture and the
        // GestureTracker user can decide if it wants to follow natural scroll settings or not
        bool natural_scroll = settings.is_natural_scroll_enabled (Clutter.InputDeviceType.TOUCHPAD_DEVICE);
        if (natural_scroll) {
            x *= -1;
            y *= -1;
        }

        delta_x += x;
        delta_y += y;

        if (!started) {
            if (delta_x != 0 || delta_y != 0) {
                if (delta_x.abs () > delta_y.abs () && orientation != HORIZONTAL ||
                    delta_y.abs () > delta_x.abs () && orientation != VERTICAL
                ) {
                    ignoring = true;
                    reset ();
                    return Clutter.EVENT_PROPAGATE;
                }

                float origin_x, origin_y;
                event.get_coords (out origin_x, out origin_y);
                Gesture gesture = build_gesture (origin_x, origin_y, delta_x, delta_y, orientation, time);
                started = true;
                direction = gesture.direction;
                on_gesture_detected (gesture, time);

                double delta = calculate_delta (delta_x, delta_y, direction);
                on_begin (delta, time);
            }
        } else {
            double delta = calculate_delta (delta_x, delta_y, direction);
            if (x == 0 && y == 0) {
                on_end (delta, time);
                reset ();
            } else {
                on_update (delta, time);
            }
        }

        return Clutter.EVENT_STOP;
    }

    private bool on_leave_event (Clutter.Event event) requires (event.get_type () == LEAVE) {
        if (!started) {
            return Clutter.EVENT_PROPAGATE;
        }

        double delta = calculate_delta (delta_x, delta_y, direction);
        on_end (delta, event.get_time ());
        reset ();

        return Clutter.EVENT_PROPAGATE;
    }

    private static bool can_handle_event (Clutter.Event event) {
        return event.get_type () == Clutter.EventType.SCROLL
            && event.get_source_device ().get_device_type () == Clutter.InputDeviceType.TOUCHPAD_DEVICE
            && event.get_scroll_direction () == Clutter.ScrollDirection.SMOOTH;
    }

    private void reset () {
        started = false;
        delta_x = 0;
        delta_y = 0;
        direction = GestureDirection.UNKNOWN;
    }

    public override void cancel_gesture () {
        if (started) {
            ignoring = true;
            reset ();
        }
    }

    private static Gesture build_gesture (float origin_x, float origin_y, double delta_x, double delta_y, Clutter.Orientation orientation, uint32 timestamp) {
        GestureDirection direction;
        if (orientation == Clutter.Orientation.HORIZONTAL) {
            direction = delta_x > 0 ? GestureDirection.RIGHT : GestureDirection.LEFT;
        } else {
            direction = delta_y > 0 ? GestureDirection.DOWN : GestureDirection.UP;
        }

        return new Gesture () {
            type = Clutter.EventType.SCROLL,
            direction = direction,
            fingers = 2,
            performed_on_device_type = Clutter.InputDeviceType.TOUCHPAD_DEVICE,
            origin_x = origin_x,
            origin_y = origin_y
        };
    }

    private static double calculate_delta (double delta_x, double delta_y, GestureDirection direction) {
        bool is_horizontal = (direction == GestureDirection.LEFT || direction == GestureDirection.RIGHT);
        double used_delta = is_horizontal ? delta_x : delta_y;
        double finish_delta = is_horizontal ? FINISH_DELTA_HORIZONTAL : FINISH_DELTA_VERTICAL;

        bool is_positive = (direction == GestureDirection.RIGHT || direction == GestureDirection.DOWN);

        return (used_delta / finish_delta) * (is_positive ? 1 : -1);
    }
}
