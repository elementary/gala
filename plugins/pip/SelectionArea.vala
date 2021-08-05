//
//  Copyright (C) 2017 Santiago León O., Adam Bieńkowski
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

public class Gala.Plugins.PIP.SelectionArea : Clutter.Actor {
    public signal void captured (int x, int y, int width, int height);
    public signal void selected (int x, int y);
    public signal void closed ();

    public Gala.WindowManager wm { get; construct; }
    public Meta.WindowActor target_actor { get; construct; }

    /**
     * Resize handlers radius.
     */
    private const double HANDLER_RADIUS = 6.0;

    /**
     * When resizing, the number of pixel the user can click outside of the handler.
     */
    private const int RESIZE_THRESHOLD = 10;

    /**
     * Minimum allowed selection size.
     */
    private const int MIN_SELECTION = 100;

    private Gala.ModalProxy? modal_proxy;
    private Gdk.Point start_point;
    private Gdk.Point end_point;
    private bool dragging = false;

    /**
     * If the user is resizing the selection area and the resize handler used.
     */
    private bool resizing = false;
    private bool resizing_top = false;
    private bool resizing_bottom = false;
    private bool resizing_left = false;
    private bool resizing_right = false;

    /**
     * Maximum size allowed for the selection area.
     */
    private Meta.Rectangle max_size;

    public SelectionArea (Gala.WindowManager wm, Meta.WindowActor target_actor) {
        Object (wm: wm, target_actor: target_actor);
    }

    construct {
        var window = target_actor.get_meta_window ();
        max_size = window.get_frame_rect ();
        start_point = { max_size.x, max_size.y };
        end_point = { max_size.x + max_size.width, max_size.y + max_size.height };
        visible = true;
        reactive = true;

        int screen_width, screen_height;
        wm.get_display ().get_size (out screen_width, out screen_height);
        width = screen_width;
        height = screen_height;

        var canvas = new Clutter.Canvas ();
        canvas.set_size (screen_width, screen_height);
        canvas.draw.connect (draw_area);
        set_content (canvas);

        canvas.invalidate ();
    }

    public override bool key_press_event (Clutter.KeyEvent e) {
        if (e.keyval == Clutter.Key.Escape) {
            close ();
            closed ();
            return true;
        }

        return false;
    }

    public override bool button_press_event (Clutter.ButtonEvent e) {
        if (dragging || e.button != 1) {
            return true;
        }

        // Check that the user clicked on a resize handler
        resizing_top = is_close_to_coord (e.y, start_point.y, RESIZE_THRESHOLD);
        resizing_bottom = is_close_to_coord (e.y, end_point.y, RESIZE_THRESHOLD);
        resizing_left = is_close_to_coord (e.x, start_point.x, RESIZE_THRESHOLD);
        resizing_right = is_close_to_coord (e.x, end_point.x, RESIZE_THRESHOLD);
        resizing = (resizing_top && resizing_left) ||
                   (resizing_top && resizing_right) ||
                   (resizing_bottom && resizing_left) ||
                   (resizing_bottom && resizing_right);

        if (resizing) {
            return true;
        }

        return true;
    }

    private static bool is_close_to_coord (float c, int target, int threshold) {
        return (c >= target - threshold) &&
               (c <= target + threshold);
    }

    public override bool button_release_event (Clutter.ButtonEvent e) {
        if (e.button != 1) {
            return true;
        }

        if (!dragging) {
            selected ((int) e.x, (int) e.y);
            close ();
            return true;
        }

        dragging = false;
        resizing = false;

        int x, y, w, h;
        get_selection_rectangle (out x, out y, out w, out h);
        close ();
        start_point = { 0, 0 };
        end_point = { 0, 0 };
        this.hide ();
        content.invalidate ();

        captured (x, y, w, h);

        return true;
    }

    public override bool motion_event (Clutter.MotionEvent e) {
        if (!resizing) {
            return true;
        }

        if (resizing) {
            resize_selection_area (e);
        }

        content.invalidate ();

        if (!dragging) {
            dragging = true;
        }

        return true;
    }

    private void resize_selection_area (Clutter.MotionEvent e) {
        if (resizing_top) {
            start_point.y = (int) e.y.clamp (max_size.y, end_point.y - MIN_SELECTION);
        } else if (resizing_bottom) {
            end_point.y = (int) e.y.clamp (start_point.y + MIN_SELECTION, max_size.y + max_size.height);
        }

        if (resizing_left) {
            start_point.x = (int) e.x.clamp (max_size.x, end_point.x - MIN_SELECTION);
        } else if (resizing_right) {
            end_point.x = (int) e.x.clamp (start_point.x + MIN_SELECTION, max_size.x + max_size.width);
        }
    }

    public void close () {
        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);

        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
        }
    }

    public void start_selection () {
        wm.get_display ().set_cursor (Meta.Cursor.CROSSHAIR);
        grab_key_focus ();

        modal_proxy = wm.push_modal ();
    }

    private void get_selection_rectangle (out int x, out int y, out int width, out int height) {
        x = start_point.x;
        y = start_point.y;
        width = end_point.x - start_point.x;
        height = end_point.y - start_point.y;
    }

    private bool draw_area (Cairo.Context ctx) {
        // Draws a full-screen colored rectangle with a smaller transparent
        // rectangle inside with border with handlers
        Clutter.cairo_clear (ctx);
        ctx.set_operator (Cairo.Operator.SOURCE);

        // Full-screen rectangle
        ctx.rectangle (0, 0, width, height);
        ctx.set_source_rgba (0.1, 0.1, 0.1, 0.8);
        ctx.fill ();

        // Transparent rectangle
        int x, y, w, h;
        get_selection_rectangle (out x, out y, out w, out h);

        ctx.rectangle (x, y, w, h);
        ctx.set_source_rgba (0.0, 0.0, 0.0, 0.0);
        ctx.fill ();

        ctx.rectangle (x, y, w, h);
        ctx.set_source_rgb (0.7, 0.7, 0.7);
        ctx.set_line_width (1.0);
        ctx.stroke ();

        // Handlers
        ctx.arc (start_point.x, start_point.y, HANDLER_RADIUS, 0.0, 2.0 * Math.PI);
        ctx.fill ();
        ctx.arc (start_point.x, end_point.y, HANDLER_RADIUS, 0.0, 2.0 * Math.PI);
        ctx.fill ();
        ctx.arc (end_point.x, start_point.y, HANDLER_RADIUS, 0.0, 2.0 * Math.PI);
        ctx.fill ();
        ctx.arc (end_point.x, end_point.y, HANDLER_RADIUS, 0.0, 2.0 * Math.PI);
        ctx.fill ();

        return true;
    }
}
