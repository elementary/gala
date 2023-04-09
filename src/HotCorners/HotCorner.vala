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



private class Gala.Barrier : Meta.Barrier {
    public bool is_hit { get; set; default = false; }
    public double pressure_x { get; set; default = 0; }
    public double pressure_y { get; set; default = 0; }

    public Barrier (Meta.Display display, int x1, int y1, int x2, int y2, Meta.BarrierDirection directions) {
        Object (display: display, x1: x1, y1: y1, x2: x2, y2: y2, directions: directions);
    }
}

public class Gala.HotCorner : Object {
    public const string POSITION_TOP_LEFT = "hotcorner-topleft";
    public const string POSITION_TOP_RIGHT = "hotcorner-topright";
    public const string POSITION_BOTTOM_LEFT = "hotcorner-bottomleft";
    public const string POSITION_BOTTOM_RIGHT = "hotcorner-bottomright";
    private const int BARRIER_SIZE = 30;

    /**
     * In order to avoid accidental triggers, don't trigger the hot corner until
     * this threshold is reached.
     */
    private const int TRIGGER_PRESSURE_THRESHOLD = 50;

    /**
     * When the mouse pointer pressures the barrier without activating the hot corner,
     * release it when this threshold is reached.
     */
    private const int RELEASE_PRESSURE_THRESHOLD = 100;

    /**
     * When the mouse pointer pressures the hot corner after activation, trigger the
     * action again when this threshold is reached.
     * Only retrigger after a minimum delay (milliseconds) since original trigger.
     */
    private const int RETRIGGER_PRESSURE_THRESHOLD = 500;
    private const int RETRIGGER_DELAY = 600;

    public signal void trigger ();

    private Gala.Barrier? vertical_barrier = null;
    private Gala.Barrier? horizontal_barrier = null;
    private bool triggered = false;
    private uint32 triggered_time;

    public HotCorner (Meta.Display display, float x, float y, float scale, string hot_corner_position) {
        add_barriers (display, x, y, scale, hot_corner_position);
    }

    public void destroy_barriers () {
        if (vertical_barrier != null) {
            vertical_barrier.destroy ();
        }

        if (horizontal_barrier != null) {
            horizontal_barrier.destroy ();
        }
    }

    private void add_barriers (Meta.Display display, float x, float y, float scale, string hot_corner_position) {
        var vrect = get_barrier_rect (x, y, scale, hot_corner_position, Clutter.Orientation.VERTICAL);
        var hrect = get_barrier_rect (x, y, scale, hot_corner_position, Clutter.Orientation.HORIZONTAL);
        var vdir = get_barrier_direction (hot_corner_position, Clutter.Orientation.VERTICAL);
        var hdir = get_barrier_direction (hot_corner_position, Clutter.Orientation.HORIZONTAL);

        vertical_barrier = new Gala.Barrier (display, vrect.x, vrect.y, vrect.x + vrect.width, vrect.y + vrect.height, vdir);
        horizontal_barrier = new Gala.Barrier (display, hrect.x, hrect.y, hrect.x + hrect.width, hrect.y + hrect.height, hdir);

        vertical_barrier.hit.connect ((event) => on_barrier_hit (vertical_barrier, event));
        horizontal_barrier.hit.connect ((event) => on_barrier_hit (horizontal_barrier, event));

        vertical_barrier.left.connect ((event) => on_barrier_left (vertical_barrier, event));
        horizontal_barrier.left.connect ((event) => on_barrier_left (horizontal_barrier, event));
    }

    private static Meta.BarrierDirection get_barrier_direction (string hot_corner_position, Clutter.Orientation orientation) {
        bool vert = (orientation == Clutter.Orientation.VERTICAL);
        switch (hot_corner_position) {
            case POSITION_TOP_LEFT:
                return vert ? Meta.BarrierDirection.POSITIVE_X : Meta.BarrierDirection.POSITIVE_Y;
            case POSITION_TOP_RIGHT:
                return vert ? Meta.BarrierDirection.NEGATIVE_X : Meta.BarrierDirection.POSITIVE_Y;
            case POSITION_BOTTOM_LEFT:
                return vert ? Meta.BarrierDirection.POSITIVE_X : Meta.BarrierDirection.NEGATIVE_Y;
            case POSITION_BOTTOM_RIGHT:
            default:
                return vert ? Meta.BarrierDirection.NEGATIVE_X : Meta.BarrierDirection.NEGATIVE_Y;
        }
    }

    private static Meta.Rectangle get_barrier_rect (float x, float y, float scale, string hot_corner_position, Clutter.Orientation orientation) {
        var barrier_size = InternalUtils.scale_to_int (BARRIER_SIZE, scale);

        int x1 = (int) x;
        int y1 = (int) y;
        int x2;
        int y2;

        bool vert = (orientation == Clutter.Orientation.VERTICAL);
        switch (hot_corner_position) {
            case POSITION_TOP_LEFT:
                x2 = vert ? x1 : x1 + barrier_size;
                y2 = vert ? y1 + barrier_size : y1;
                break;
            case POSITION_TOP_RIGHT:
                x2 = vert ? x1 : x1 - barrier_size;
                y2 = vert ? y1 + barrier_size : y1;
                break;
            case POSITION_BOTTOM_LEFT:
                x2 = vert ? x1 : x1 + barrier_size;
                y2 = vert ? y1 - barrier_size : y1;
                break;
            case POSITION_BOTTOM_RIGHT:
            default:
                x2 = vert ? x1 : x1 - barrier_size;
                y2 = vert ? y1 - barrier_size : y1;
                break;
        }

        return { x1, y1, x2 - x1, y2 - y1 };
    }

    private void on_barrier_hit (Gala.Barrier barrier, Meta.BarrierEvent event) {
        barrier.is_hit = true;
        barrier.pressure_x += event.dx;
        barrier.pressure_y += event.dy;

        var pressure = (barrier == vertical_barrier) ?
            barrier.pressure_x.abs () :
            barrier.pressure_y.abs ();

        if (!triggered && vertical_barrier.is_hit && horizontal_barrier.is_hit) {
            if (pressure.abs () > TRIGGER_PRESSURE_THRESHOLD) {
                trigger_hot_corner ();
                pressure = 0;
                triggered_time = event.time;
            }
        }

        if (!triggered && pressure.abs () > RELEASE_PRESSURE_THRESHOLD) {
            barrier.release (event);
        }

        if (triggered && pressure.abs () > RETRIGGER_PRESSURE_THRESHOLD && event.time > RETRIGGER_DELAY + triggered_time) {
            trigger_hot_corner ();
        }
    }

    private void on_barrier_left (Gala.Barrier barrier, Meta.BarrierEvent event) {
        barrier.is_hit = false;
        barrier.pressure_x = 0;
        barrier.pressure_y = 0;

        if (!vertical_barrier.is_hit && !horizontal_barrier.is_hit) {
            triggered = false;
        }
    }

    private void trigger_hot_corner () {
        triggered = true;
        vertical_barrier.pressure_x = 0;
        vertical_barrier.pressure_y = 0;
        horizontal_barrier.pressure_x = 0;
        horizontal_barrier.pressure_y = 0;
        trigger ();
    }
}
