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

    public signal void on_begin (double delta, uint64 time);
    public signal void on_update (double delta, uint64 time);
    public signal void on_end (double delta, uint64 time);

    public Clutter.Actor actor { get; construct; }
    public Clutter.Orientation orientation { get; construct; }

    private bool started;
    private double delta_x;
    private double delta_y;

    construct {
        started = false;
        delta_x = 0;
        delta_y = 0;
    }

    public ScrollBackend (Clutter.Actor actor, Clutter.Orientation orientation) {
        Object(actor: actor, orientation: orientation);

        actor.scroll_event.connect(on_scroll_event);
    }

    private bool on_scroll_event (Clutter.ScrollEvent event) {
        if (!can_handle_event (event)) {
            return false;
        }

        double x, y;
        event.get_scroll_delta (out x, out y);
        delta_x += x;
        delta_y += y;

        double delta = calculate_delta (delta_x, delta_y, orientation);
        uint64 time = event.get_time ();

        if (!started) {
            started = true;            
            on_begin (delta, time);
        } else if (x == 0 && y == 0) {
            started = false;
            delta_x = 0;
            delta_y = 0;
            on_end (delta, time);
        } else {
            on_update (delta, time);
        }

        return true;
    }

    private static bool can_handle_event (Clutter.ScrollEvent event) {
        return event.get_type () == Clutter.EventType.SCROLL
            && event.get_source_device ().get_device_type () == Clutter.InputDeviceType.TOUCHPAD_DEVICE
            && event.get_scroll_direction () == Clutter.ScrollDirection.SMOOTH;
    }

    private static double calculate_delta (double delta_x, double delta_y, Clutter.Orientation orientation) {
        double used_delta = (orientation == Clutter.Orientation.HORIZONTAL)
            ? delta_x
            : delta_y;
        double finish_delta = (orientation == Clutter.Orientation.HORIZONTAL)
            ? FINISH_DELTA_HORIZONTAL
            : FINISH_DELTA_VERTICAL;
        double normalized_delta = (used_delta / finish_delta).clamp (-1, 1);
        return normalized_delta;
    }
}
