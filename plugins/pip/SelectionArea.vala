/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017 Santiago León O.
 *                         2017 Adam Bieńkowski
 *                         2024 elementary, Inc. (https://elementary.io)
 */

public class Gala.Plugins.PIP.SelectionArea : CanvasActor {
    public const int MIN_SELECTION = 100;

    private const int HANDLER_RADIUS = 6;
    private const int BORDER_WIDTH = 2;
    private const int RESIZE_THRESHOLD = 10;
    private const int CONFIRM_BUTTON_SIZE = 60;

    public signal void captured (int x, int y, int width, int height);
    public signal void closed ();

    public Gala.WindowManager wm { get; construct; }
    public Meta.WindowActor target_actor { get; construct; }

    /**
     * A clone of the "target_actor" displayed and clipped while the selection
     * mask is visible.
     */
    private Clutter.Actor clone;

    private Mtk.Rectangle max_size;
    private Mtk.Rectangle selection;
    private float monitor_scale;
    private Clutter.Actor confirm_button;
    private Gala.ModalProxy? modal_proxy;

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

    public SelectionArea (WindowManager wm, Meta.WindowActor target_actor) {
        Object (wm: wm, target_actor: target_actor);
    }

    construct {
        unowned var window = target_actor.meta_window;

        max_size = window.get_frame_rect ();
        selection = max_size;
        visible = true;
        reactive = true;

        clone = new Clutter.Clone (target_actor) {
            x = target_actor.x,
            y = target_actor.y
        };
        wm.ui_group.add_child (clone);

        unowned var display = wm.get_display ();

        int screen_width, screen_height;
        display.get_size (out screen_width, out screen_height);
        width = screen_width;
        height = screen_height;

        var click_action = new Clutter.ClickAction ();
        click_action.clicked.connect (capture_selected_area);

        confirm_button = new Clutter.Actor () {
            reactive = true
        };
        confirm_button.add_action (click_action);
        add_child (confirm_button);

        monitor_scale = display.get_monitor_scale (window.get_monitor ());

        var confirm_button_pixbuf = get_confirm_button_pixbuf (monitor_scale);
        if (confirm_button_pixbuf != null) {
            var image = new Image.from_pixbuf (confirm_button_pixbuf);
            confirm_button.set_content (image);
            confirm_button.set_size (confirm_button_pixbuf.width, confirm_button_pixbuf.height);
        } else {
            // we'll just make this red so there's at least something as an
            // indicator that loading failed. Should never happen and this
            // works as good as some weird fallback-image-failed-to-load pixbuf
            var size = Utils.scale_to_int (CONFIRM_BUTTON_SIZE, monitor_scale);
            confirm_button.set_size (size, size);
            confirm_button.background_color = { 255, 0, 0, 255 };
        }

        update_confirm_button_position ();
    }

    private static Gdk.Pixbuf? get_confirm_button_pixbuf (float scale) {
        try {
            return new Gdk.Pixbuf.from_resource_at_scale (
                Config.RESOURCEPATH + "/buttons/resize.svg",
                -1,
                Utils.scale_to_int (CONFIRM_BUTTON_SIZE, scale),
                true
            );
        } catch (Error e) {
            critical (e.message);
            return null;
        }
    }

    public override bool key_press_event (Clutter.Event event) {
        switch (event.get_key_symbol ()) {
            case Clutter.Key.Escape:
                close ();
                closed ();

                return Clutter.EVENT_STOP;
            case Clutter.Key.Return:
            case Clutter.Key.KP_Enter:
                capture_selected_area ();

                return Clutter.EVENT_STOP;
        }

        return Clutter.EVENT_PROPAGATE;
    }

    private void capture_selected_area () {
        close ();
        captured (selection.x, selection.y, selection.width, selection.height);
    }

    public override bool button_press_event (Clutter.Event event) {
        if (dragging || resizing || event.get_button () != Clutter.Button.PRIMARY) {
            return Clutter.EVENT_STOP;
        }

        float event_x, event_y;
        event.get_coords (out event_x, out event_y);

        // Check that the user clicked on a resize handler
        resizing_top = is_close_to_coord (event_y, selection.y, RESIZE_THRESHOLD);
        resizing_bottom = is_close_to_coord (event_y, selection.y + selection.height, RESIZE_THRESHOLD);
        resizing_left = is_close_to_coord (event_x, selection.x, RESIZE_THRESHOLD);
        resizing_right = is_close_to_coord (event_x, selection.x + selection.width, RESIZE_THRESHOLD);
        resizing = (resizing_top && resizing_left) ||
                   (resizing_top && resizing_right) ||
                   (resizing_bottom && resizing_left) ||
                   (resizing_bottom && resizing_right);

        if (resizing) {
            return Clutter.EVENT_STOP;
        }

        dragging = selection.contains_rect ({ (int) event_x, (int) event_y, 1, 1 });
        if (dragging) {
            drag_x = event_x - selection.x;
            drag_y = event_y - selection.y;

#if HAS_MUTTER48
            wm.get_display ().set_cursor (MOVE);
#else
            wm.get_display ().set_cursor (MOVE_OR_RESIZE_WINDOW);
#endif

            return Clutter.EVENT_STOP;
        }

        selection.x = (int) event_x;
        selection.y = (int) event_y;

        return Clutter.EVENT_STOP;
    }

    private static bool is_close_to_coord (float c, int target, int threshold) {
        return (c >= target - threshold) &&
               (c <= target + threshold);
    }

    public override bool button_release_event (Clutter.Event event) {
        if (event.get_button () != Clutter.Button.PRIMARY) {
            return Clutter.EVENT_STOP;
        }

        float event_x, event_y;
        event.get_coords (out event_x, out event_y);

        if (!resizing && !dragging && !selection.contains_rect ({ (int) event_x, (int) event_y, 0, 0 })) {
            close ();
            closed ();
            return true;
        }

        dragging = false;
        resizing = false;
        wm.get_display ().set_cursor (DEFAULT);

        return Clutter.EVENT_STOP;
    }

    public override bool motion_event (Clutter.Event event) {
        set_mouse_cursor_on_motion (event);

        if (!resizing && !dragging) {
            return Clutter.EVENT_STOP;
        }

        if (resizing) {
            resize_selection_area (event);
        } else if (dragging) {
            drag_selection_area (event);
        }

        content.invalidate ();

        return Clutter.EVENT_STOP;
    }

    private void resize_selection_area (Clutter.Event event) {
        float event_x, event_y;
        event.get_coords (out event_x, out event_y);

        var start_x = selection.x;
        var end_x = selection.x + selection.width;
        var start_y = selection.y;
        var end_y = selection.y + selection.height;

        if (resizing_top) {
            start_y = (int) event_y.clamp (max_size.y, end_y - MIN_SELECTION);
        } else if (resizing_bottom) {
            end_y = (int) event_y.clamp (start_y + MIN_SELECTION, max_size.y + max_size.height);
        }

        if (resizing_left) {
            start_x = (int) event_x.clamp (max_size.x, end_x - MIN_SELECTION);
        } else if (resizing_right) {
            end_x = (int) event_x.clamp (start_x + MIN_SELECTION, max_size.x + max_size.width);
        }

        selection = { start_x, start_y, end_x - start_x, end_y - start_y };

        update_confirm_button_position ();
    }

    private void drag_selection_area (Clutter.Event e) {
        float event_x, event_y;
        e.get_coords (out event_x, out event_y);

        selection.x = (int) (event_x - drag_x).clamp (max_size.x, max_size.x + max_size.width - selection.width);
        selection.y = (int) (event_y - drag_y).clamp (max_size.y, max_size.y + max_size.height - selection.height);

        update_confirm_button_position ();
    }

    private void update_confirm_button_position () {
        confirm_button.set_position (
            selection.x + (selection.width - (int) confirm_button.width) / 2,
            selection.y + (selection.height - (int) confirm_button.height) / 2
        );
    }

    private void set_mouse_cursor_on_motion (Clutter.Event e) {
        if (resizing || dragging) {
            return;
        }

        float event_x, event_y;
        e.get_coords (out event_x, out event_y);

        var top = is_close_to_coord (event_y, selection.y, RESIZE_THRESHOLD);
        var bottom = is_close_to_coord (event_y, selection.y + selection.height, RESIZE_THRESHOLD);
        var left = is_close_to_coord (event_x, selection.x, RESIZE_THRESHOLD);
        var right = is_close_to_coord (event_x, selection.x + selection.width, RESIZE_THRESHOLD);

        if (top && left) {
            wm.get_display ().set_cursor (NW_RESIZE);
        } else if (top && right) {
            wm.get_display ().set_cursor (NE_RESIZE);
        } else if (bottom && left) {
            wm.get_display ().set_cursor (SW_RESIZE);
        } else if (bottom && right) {
            wm.get_display ().set_cursor (SE_RESIZE);
        } else {
            wm.get_display ().set_cursor (DEFAULT);
        }
    }

    public void close () {
        wm.get_display ().set_cursor (DEFAULT);
        wm.ui_group.remove_child (clone);

        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
        }
    }

    public void start_selection () {
        grab_key_focus ();

        modal_proxy = wm.push_modal (this);
    }

    protected override void draw (Cairo.Context ctx, int width, int height) {
        // Draws a full-screen colored rectangle with a smaller transparent
        // rectangle inside with border with handlers
        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.restore ();

        // Full-screen rectangle
        ctx.save ();
        ctx.set_operator (Cairo.Operator.OVER);
        ctx.rectangle (0, 0, width, height);
        ctx.set_source_rgba (0.0, 0.0, 0.0, 0.5);
        ctx.fill ();
        ctx.restore ();

        // Transparent rectangle
        ctx.save ();
        ctx.set_operator (Cairo.Operator.SOURCE);
        ctx.rectangle (selection.x, selection.y, selection.width, selection.height);
        ctx.set_source_rgba (0.0, 0.0, 0.0, 0.0);
        ctx.fill ();
        ctx.restore ();

        ctx.save ();

        var accent_color = Drawing.StyleManager.get_instance ().theme_accent_color;
        ctx.set_source_rgba (accent_color.red, accent_color.green, accent_color.blue, 1.0);

        // Border
        ctx.set_operator (Cairo.Operator.OVER);
        ctx.rectangle (selection.x, selection.y, selection.width, selection.height);
        ctx.set_line_width (Utils.scale_to_int (BORDER_WIDTH, monitor_scale));
        ctx.stroke ();

        // Handlers
        var start_x = selection.x;
        var end_x = selection.x + selection.width;
        var start_y = selection.y;
        var end_y = selection.y + selection.height;
        var scaled_handler_radius = Utils.scale_to_int (HANDLER_RADIUS, monitor_scale);

        ctx.arc (start_x, start_y, scaled_handler_radius, 0.0, 2.0 * Math.PI);
        ctx.fill ();
        ctx.arc (start_x, end_y, scaled_handler_radius, 0.0, 2.0 * Math.PI);
        ctx.fill ();
        ctx.arc (end_x, start_y, scaled_handler_radius, 0.0, 2.0 * Math.PI);
        ctx.fill ();
        ctx.arc (end_x, end_y, scaled_handler_radius, 0.0, 2.0 * Math.PI);
        ctx.fill ();

        ctx.restore ();
    }
}
