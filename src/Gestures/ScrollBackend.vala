/*
 * Copyright 2021 elementary, Inc (https://elementary.io)
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
public class Gala.ScrollBackend : Object {
    // Mutter does not expose the size of the touchpad, so we use the same values as GTK apps.
    // From GNOME Shell, TOUCHPAD_BASE_[WIDTH|HEIGHT] / SCROLL_MULTIPLIER
    // https://gitlab.gnome.org/GNOME/gnome-shell/-/blob/master/js/ui/swipeTracker.js
    private const double FINISH_DELTA_HORIZONTAL = 40;
    private const double FINISH_DELTA_VERTICAL = 30;

    public signal void on_gesture_detected (Gesture gesture);
    public signal void on_begin (double delta, uint64 time);
    public signal void on_update (double delta, uint64 time);
    public signal void on_end (double delta, uint64 time);

    public Clutter.Actor actor { get; construct; }
    public Clutter.Orientation orientation { get; construct; }
    public GestureSettings settings { get; construct; }

    private bool started;
    private double delta_x;
    private double delta_y;
    private GestureDirection direction;

    construct {
        started = false;
        delta_x = 0;
        delta_y = 0;
        direction = GestureDirection.UNKNOWN;
    }

    public ScrollBackend (Clutter.Actor actor, Clutter.Orientation orientation, GestureSettings settings) {
        Object (actor: actor, orientation: orientation, settings: settings);

        actor.scroll_event.connect (on_scroll_event);
    }

    private bool on_scroll_event (Clutter.ScrollEvent event) {
        if (!can_handle_event (event)) {
            return false;
        }

        uint64 time = event.get_time ();
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
                Gesture gesture = build_gesture (delta_x, delta_y, orientation);
                started = true;
                direction = gesture.direction;
                on_gesture_detected (gesture);

                double delta = calculate_delta (delta_x, delta_y, direction);
                on_begin (delta, time);
            }
        } else {
            double delta = calculate_delta (delta_x, delta_y, direction);
            if (x == 0 && y == 0) {
                started = false;
                delta_x = 0;
                delta_y = 0;
                direction = GestureDirection.UNKNOWN;
                on_end (delta, time);
            } else {
                on_update (delta, time);
            }
        }

        return true;
    }

    private static bool can_handle_event (Clutter.ScrollEvent event) {
        return event.get_type () == Clutter.EventType.SCROLL
            && event.get_source_device ().get_device_type () == Clutter.InputDeviceType.TOUCHPAD_DEVICE
            && event.get_scroll_direction () == Clutter.ScrollDirection.SMOOTH;
    }

    private static Gesture build_gesture (double delta_x, double delta_y, Clutter.Orientation orientation) {
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
            performed_on_device_type = Clutter.InputDeviceType.TOUCHPAD_DEVICE
        };
    }

    private static double calculate_delta (double delta_x, double delta_y, GestureDirection direction) {
        bool is_horizontal = (direction == GestureDirection.LEFT || direction == GestureDirection.RIGHT);
        double used_delta = is_horizontal ? delta_x : delta_y;
        double finish_delta = is_horizontal ? FINISH_DELTA_HORIZONTAL : FINISH_DELTA_VERTICAL;

        bool is_positive = (direction == GestureDirection.RIGHT || direction == GestureDirection.DOWN);
        double clamp_low = is_positive ? 0 : -1;
        double clamp_high = is_positive ? 1 : 0;

        double normalized_delta = (used_delta / finish_delta).clamp (clamp_low, clamp_high).abs ();
        return normalized_delta;
    }
}
