/*
 * Copyright 2021 elementary, Inc (https://elementary.io)
 *           2017 Santiago León O., Adam Bieńkowski
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

public class Gala.Plugins.PIP.SelectionArea : Clutter.Actor {
    public signal void captured (int x, int y, int width, int height);
    public signal void closed ();

    public Gala.WindowManager wm { get; construct; }
    public Meta.WindowActor target_actor { get; construct; }

    /**
     * A clone of the "target_actor" displayed and clipped while the selection
     * mask is visible.
     */
    public Clutter.Actor clone { get; construct; }

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

    /**
     * Confirm button size.
     */
    private const int CONFIRM_BUTTON_SIZE = 60;

    private Gala.ModalProxy? modal_proxy;
    private Gdk.Point start_point;
    private Gdk.Point end_point;

    /**
     * If the user is resizing the selection area and the resize handler used.
     */
    private bool resizing = false;
    private bool resizing_top = false;
    private bool resizing_bottom = false;
    private bool resizing_left = false;
    private bool resizing_right = false;

    /**
     * If the user is dragging the selection area and the starting point.
     */
    private bool dragging = false;
    private float drag_x = 0.0f;
    private float drag_y = 0.0f;

    /**
     * Maximum size allowed for the selection area.
     */
    private Meta.Rectangle max_size;

    /**
     * Confirm button texture.
     */
    Cairo.ImageSurface? confirm_button_img = null;

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

        clone = new Clutter.Clone (target_actor);
        clone.x = target_actor.x;
        clone.y = target_actor.y;
        wm.ui_group.add_child (clone);
        target_actor.visible = false;

        int screen_width, screen_height;
        wm.get_display ().get_size (out screen_width, out screen_height);
        width = screen_width;
        height = screen_height;

        var confirm_button_pixbuf = Gala.Utils.get_confirm_button_pixbuf (CONFIRM_BUTTON_SIZE);
        if (confirm_button_pixbuf != null) {
            confirm_button_img = new Cairo.ImageSurface (Cairo.Format.ARGB32, CONFIRM_BUTTON_SIZE, CONFIRM_BUTTON_SIZE);
            Cairo.Context img_ctx = new Cairo.Context (confirm_button_img);

            Gdk.cairo_set_source_pixbuf (img_ctx, confirm_button_pixbuf, 0, 0);
            img_ctx.rectangle (0.0, 0.0, CONFIRM_BUTTON_SIZE, CONFIRM_BUTTON_SIZE);
            img_ctx.paint ();
        }

        var canvas = new Clutter.Canvas ();
        canvas.set_size (screen_width, screen_height);
        canvas.draw.connect (draw_area);
        set_content (canvas);

        canvas.invalidate ();
    }

    public override bool key_press_event (Clutter.KeyEvent e) {
        switch (e.keyval) {
            case Clutter.Key.Escape:
                close ();
                closed ();
                return true;
            case Clutter.Key.Return:
            case Clutter.Key.KP_Enter:
                capture_selected_area ();
                return true;
        }

        return false;
    }

    private void capture_selected_area () {
        int x, y, w, h;
        get_selection_rectangle (out x, out y, out w, out h);
        close ();
        this.hide ();
        content.invalidate ();
        captured (x, y, w, h);
    }

    public override bool button_press_event (Clutter.ButtonEvent e) {
        if (e.button != 1) {
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

        // Click on the confirm button
        var confirm_button_pressed =
            is_close_to_coord (e.x, (start_point.x + end_point.x) / 2, CONFIRM_BUTTON_SIZE / 2) &&
            is_close_to_coord (e.y, (start_point.y + end_point.y) / 2, CONFIRM_BUTTON_SIZE / 2);
        if (confirm_button_pressed) {
            capture_selected_area ();
            return true;
        }

        // Allow to drag & drop the resize area when clicking inside it
        dragging = is_in_selection_area (e.x, e.y);

        if (dragging) {
            drag_x = e.x - start_point.x;
            drag_y = e.y - start_point.y;
            return true;
        }

        return true;
    }

    private static bool is_close_to_coord (float c, int target, int threshold) {
        return (c >= target - threshold) &&
               (c <= target + threshold);
    }

    private bool is_in_selection_area (float x, float y) {
        return (x >= start_point.x) &&
               (x <= end_point.x) &&
               (y >= start_point.y) &&
               (y <= end_point.y);
    }

    public override bool button_release_event (Clutter.ButtonEvent e) {
        if (e.button != 1) {
            return true;
        }

        if (!resizing && !dragging) {
            close ();
            closed ();
        }

        dragging = false;
        resizing = false;
        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);

        return true;
    }

    public override bool motion_event (Clutter.MotionEvent e) {
        set_mouse_cursor_on_motion (e);

        if (!resizing && !dragging) {
            return true;
        }

        if (resizing) {
            resize_selection_area (e);
        } else if (dragging) {
            drag_selection_area (e);
        }

        content.invalidate ();
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

    private void drag_selection_area (Clutter.MotionEvent e) {
        var width = end_point.x - start_point.x;
        var height = end_point.y - start_point.y;

        var x = (int) (e.x - drag_x).clamp (max_size.x, max_size.x + max_size.width - width);
        var y = (int) (e.y - drag_y).clamp (max_size.y, max_size.y + max_size.height - height);

        end_point.x = x + width;
        end_point.y = y + height;
        start_point.x = x;
        start_point.y = y;
    }

    private void set_mouse_cursor_on_motion (Clutter.MotionEvent e) {
        if (resizing) {
            return;
        }

        var cursor = Meta.Cursor.DEFAULT;

        if (dragging) {
            cursor = Meta.Cursor.MOVE_OR_RESIZE_WINDOW;
        } else {
            var top = is_close_to_coord (e.y, start_point.y, RESIZE_THRESHOLD);
            var bottom = is_close_to_coord (e.y, end_point.y, RESIZE_THRESHOLD);
            var left = is_close_to_coord (e.x, start_point.x, RESIZE_THRESHOLD);
            var right = is_close_to_coord (e.x, end_point.x, RESIZE_THRESHOLD);

            if (top && left) {
                cursor = Meta.Cursor.NW_RESIZE;
            } else if (top && right) {
                cursor = Meta.Cursor.NE_RESIZE;
            } else if (bottom && left) {
                cursor = Meta.Cursor.SW_RESIZE;
            } else if (bottom && right) {
                cursor = Meta.Cursor.SE_RESIZE;
            }
        }

        wm.get_display ().set_cursor (cursor);
    }

    public void close () {
        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);
        wm.ui_group.remove_child (clone);
        target_actor.visible = true;

        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
        }
    }

    public void start_selection () {
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

        // Confirm button
        if (confirm_button_img != null) {
            var img_x = ((start_point.x + end_point.x) / 2) - (CONFIRM_BUTTON_SIZE / 2);
            var img_y = ((start_point.y + end_point.y) / 2) - (CONFIRM_BUTTON_SIZE / 2);

            ctx.set_source_surface (confirm_button_img, img_x, img_y);
            ctx.rectangle (img_x, img_y, CONFIRM_BUTTON_SIZE, CONFIRM_BUTTON_SIZE);
            ctx.clip ();
            ctx.paint ();
        }

        // Hide the masked part of the actor
        clone.set_clip (start_point.x - clone.x, start_point.y - clone.y, w, h);

        return true;
    }
}
