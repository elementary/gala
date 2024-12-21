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
public class Gala.ScrollBackend : Object, GestureBackend {
    // Mutter does not expose the size of the touchpad, so we use the same values as GTK apps.
    // From GNOME Shell, TOUCHPAD_BASE_[WIDTH|HEIGHT] / SCROLL_MULTIPLIER
    // https://gitlab.gnome.org/GNOME/gnome-shell/-/blob/master/js/ui/swipeTracker.js
    private const double FINISH_DELTA_HORIZONTAL = 40;
    private const double FINISH_DELTA_VERTICAL = 30;

    public Clutter.Actor actor { get; construct; }
    public Clutter.Orientation orientation { get; construct; }

    private bool started;
    private double delta_x;
    private double delta_y;
    private GestureAction.Direction direction;

    construct {
        started = false;
        delta_x = 0;
        delta_y = 0;
        direction = FORWARD;
    }

    public ScrollBackend (Clutter.Actor actor, Clutter.Orientation orientation) {
        Object (actor: actor, orientation: orientation);

        actor.scroll_event.connect (on_scroll_event);
    }

#if HAS_MUTTER45
    private bool on_scroll_event (Clutter.Event event) {
#else
    private bool on_scroll_event (Clutter.ScrollEvent event) {
#endif
        if (!can_handle_event (event)) {
            return false;
        }

        var time = event.get_time ();
        double x, y;
        event.get_scroll_delta (out x, out y);

        // Scroll events apply the natural scroll preferences out of the box
        // Standardize them so the direction matches the physical direction of the gesture and the
        // GestureTracker user can decide if it wants to follow natural scroll settings or not
        bool natural_scroll = GestureSettings.is_natural_scroll_enabled (Clutter.InputDeviceType.TOUCHPAD_DEVICE);
        if (!natural_scroll) {
            x *= -1;
            y *= -1;
        }

        delta_x += x;
        delta_y += y;

        if (!started) {
            if (delta_x != 0 || delta_y != 0) {
                float origin_x, origin_y;
                event.get_coords (out origin_x, out origin_y);
                GestureAction action = build_gesture (delta_x, delta_y);
                started = true;
                direction = action.direction;
                on_gesture_detected (action, time);

                double delta = calculate_delta (delta_x, delta_y);
                on_begin (delta, time);
            }
        } else {
            double delta = calculate_delta (delta_x, delta_y);
            if (x == 0 && y == 0) {
                started = false;
                delta_x = 0;
                delta_y = 0;
                direction = FORWARD;
                on_end (delta, time);
            } else {
                on_update (delta, time);
            }
        }

        return true;
    }

    private GestureAction build_gesture (double delta_x, double delta_y) {
        GestureDirection direction;
        if (orientation == HORIZONTAL) {
            direction = delta_x > 0 ? GestureDirection.RIGHT : GestureDirection.LEFT;
        } else {
            direction = delta_y > 0 ? GestureDirection.DOWN : GestureDirection.UP;
        }

        return GestureSettings.get_action (2, direction);
    }

    private double calculate_delta (double delta_x, double delta_y) {
        bool is_horizontal = orientation == HORIZONTAL;
        double used_delta = is_horizontal ? delta_x : delta_y;
        double finish_delta = is_horizontal ? FINISH_DELTA_HORIZONTAL : FINISH_DELTA_VERTICAL;

        bool is_positive = direction == FORWARD;

        return (used_delta / finish_delta) * (is_positive ? 1 : -1);
    }

#if HAS_MUTTER45
    private static bool can_handle_event (Clutter.Event event) {
#else
    private static bool can_handle_event (Clutter.ScrollEvent event) {
#endif
        return event.get_type () == Clutter.EventType.SCROLL
            && event.get_source_device ().get_device_type () == Clutter.InputDeviceType.TOUCHPAD_DEVICE
            && event.get_scroll_direction () == Clutter.ScrollDirection.SMOOTH;
    }
}
