/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017 Santiago León O.
 *                         2017 Adam Bieńkowski
 *                         2024 elementary, Inc. (https://elementary.io)
 */

public class Gala.Plugins.PIP.SelectionArea : CanvasActor {
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
    private Mtk.Rectangle max_size;

    /**
     * Confirm button texture.
     */
    Cairo.ImageSurface? confirm_button_img = null;

    public SelectionArea (Gala.WindowManager wm, Meta.WindowActor target_actor) {
        Object (wm: wm, target_actor: target_actor);
    }

    construct {
        unowned var window = target_actor.meta_window;
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
    }

    public override bool key_press_event (Clutter.Event e) {
        switch (e.get_key_symbol ()) {
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
        hide ();
        content.invalidate ();
        captured (x, y, w, h);
    }

    public override bool button_press_event (Clutter.Event e) {
        if (dragging || resizing || e.get_button () != Clutter.Button.PRIMARY) {
            return true;
        }

        float press_x, press_y;
        e.get_coords (out press_x, out press_y);

        // Check that the user clicked on a resize handler
        resizing_top = is_close_to_coord (press_y, start_point.y, RESIZE_THRESHOLD);
        resizing_bottom = is_close_to_coord (press_y, end_point.y, RESIZE_THRESHOLD);
        resizing_left = is_close_to_coord (press_x, start_point.x, RESIZE_THRESHOLD);
        resizing_right = is_close_to_coord (press_x, end_point.x, RESIZE_THRESHOLD);
        resizing = (resizing_top && resizing_left) ||
                   (resizing_top && resizing_right) ||
                   (resizing_bottom && resizing_left) ||
                   (resizing_bottom && resizing_right);

        if (resizing) {
            return true;
        }

        // Click on the confirm button
        var confirm_button_pressed =
            is_close_to_coord (press_x, (start_point.x + end_point.x) / 2, CONFIRM_BUTTON_SIZE / 2) &&
            is_close_to_coord (press_y, (start_point.y + end_point.y) / 2, CONFIRM_BUTTON_SIZE / 2);

        if (confirm_button_pressed) {
            capture_selected_area ();
            return true;
        }

        // Allow to drag & drop the resize area when clicking inside it
        dragging = is_in_selection_area (press_x, press_y);

        if (dragging) {
            drag_x = press_x - start_point.x;
            drag_y = press_y - start_point.y;
            return true;
        }

        start_point = { (int) press_x, (int) press_y }; // ???

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

    public override bool button_release_event (Clutter.Event e) {
        if (e.get_button () != Clutter.Button.PRIMARY) {
            return true;
        }

        // ???
        if (!resizing && !dragging) {
            close ();
            closed ();
            return true;
        }

        dragging = false;
        resizing = false;
        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);

        return true;
    }

    public override bool motion_event (Clutter.Event e) {
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

    private void resize_selection_area (Clutter.Event e) {
        float event_x, event_y;
        e.get_coords (out event_x, out event_y);

        if (resizing_top) {
            start_point.y = (int) event_y.clamp (max_size.y, end_point.y - MIN_SELECTION);
        } else if (resizing_bottom) {
            end_point.y = (int) event_y.clamp (start_point.y + MIN_SELECTION, max_size.y + max_size.height);
        }

        if (resizing_left) {
            start_point.x = (int) event_x.clamp (max_size.x, end_point.x - MIN_SELECTION);
        } else if (resizing_right) {
            end_point.x = (int) event_x.clamp (start_point.x + MIN_SELECTION, max_size.x + max_size.width);
        }
    }

    private void drag_selection_area (Clutter.Event e) {
        var width = end_point.x - start_point.x;
        var height = end_point.y - start_point.y;

        float event_x, event_y;
        e.get_coords (out event_x, out event_y);

        var x = (int) (event_x - drag_x).clamp (max_size.x, max_size.x + max_size.width - width);
        var y = (int) (event_y - drag_y).clamp (max_size.y, max_size.y + max_size.height - height);

        end_point.x = x + width;
        end_point.y = y + height;
        start_point.x = x;
        start_point.y = y;
    }

    private void set_mouse_cursor_on_motion (Clutter.Event e) {
        // ???
        if (resizing) {
            return;
        }

        var cursor = Meta.Cursor.DEFAULT;

        if (dragging) {
            cursor = Meta.Cursor.MOVE_OR_RESIZE_WINDOW;
        } else {
            float event_x, event_y;
            e.get_coords (out event_x, out event_y);

            var top = is_close_to_coord (event_y, start_point.y, RESIZE_THRESHOLD);
            var bottom = is_close_to_coord (event_y, end_point.y, RESIZE_THRESHOLD);
            var left = is_close_to_coord (event_x, start_point.x, RESIZE_THRESHOLD);
            var right = is_close_to_coord (event_x, end_point.x, RESIZE_THRESHOLD);

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

        modal_proxy = wm.push_modal (this);
    }

    private void get_selection_rectangle (out int x, out int y, out int width, out int height) {
        x = start_point.x;
        y = start_point.y;
        width = end_point.x - start_point.x;
        height = end_point.y - start_point.y;
    }

    protected override void draw (Cairo.Context ctx, int width, int height) {
        // Draws a full-screen colored rectangle with a smaller transparent
        // rectangle inside with border with handlers
        ctx.save ();

        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();

        ctx.restore ();

        //  if (!dragging) {
        //      return;
        //  }

        ctx.set_operator (Cairo.Operator.SOURCE);

        // Full-screen rectangle
        ctx.rectangle (0, 0, width, height);
        ctx.set_source_rgba (0.0, 0.0, 0.0, 0.0);
        ctx.fill ();

        // Transparent rectangle
        int x, y, w, h;
        get_selection_rectangle (out x, out y, out w, out h);

        ctx.rectangle (x, y, w, h);
        ctx.set_source_rgba (0.1, 0.1, 0.1, 0.2);
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
    }
}
