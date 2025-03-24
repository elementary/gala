/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017 Santiago León O.
 *                         2017 Adam Bieńkowski
 *                         2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.SelectionArea : CanvasActor {
    public signal void closed ();

    public WindowManager wm { get; construct; }

    public bool cancelled { get; private set; }

    private ModalProxy? modal_proxy;
    private Graphene.Point start_point;
    private Graphene.Point end_point;
    private bool dragging = false;
    private bool clicked = false;

    public SelectionArea (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        start_point.init (0, 0);
        end_point.init (0, 0);
        visible = true;
        reactive = true;

        int screen_width, screen_height;
        wm.get_display ().get_size (out screen_width, out screen_height);
        width = screen_width;
        height = screen_height;
    }

    public override bool key_press_event (Clutter.Event e) {
        if (e.get_key_symbol () == Clutter.Key.Escape) {
            close ();
            cancelled = true;
            closed ();
            return true;
        }

        return false;
    }

    public override bool button_press_event (Clutter.Event e) {
        if (dragging || e.get_button () != Clutter.Button.PRIMARY) {
            return true;
        }

        clicked = true;

        float x, y;
        e.get_coords (out x, out y);
        start_point.init (x, y);

        return true;
    }

    public override bool button_release_event (Clutter.Event e) {
        if (e.get_button () != Clutter.Button.PRIMARY) {
            return true;
        }

        if (!dragging) {
            close ();
            cancelled = true;
            closed ();
            return true;
        }

        dragging = false;
        clicked = false;

        close ();
        this.hide ();
        content.invalidate ();

        closed ();
        return true;
    }

    public override bool motion_event (Clutter.Event e) {
        if (!clicked) {
            return true;
        }

        float x, y;
        e.get_coords (out x, out y);
        end_point.init (x, y);
        content.invalidate ();

        if (!dragging) {
            dragging = true;
        }

        return true;
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

        modal_proxy = wm.push_modal (this);
    }

    public Graphene.Rect get_selection_rectangle () {
        return Graphene.Rect () {
            origin = start_point,
            size = Graphene.Size.zero ()
        }.expand (end_point);
    }

    protected override void draw (Cairo.Context ctx, int width, int height) {
        ctx.save ();

        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();

        ctx.restore ();

        if (!dragging) {
            return;
        }

        ctx.translate (0.5, 0.5);

        var rect = get_selection_rectangle ();
        ctx.rectangle (rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
        ctx.set_source_rgba (0.1, 0.1, 0.1, 0.2);
        ctx.fill ();

        ctx.rectangle (rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
        ctx.set_source_rgb (0.7, 0.7, 0.7);
        ctx.set_line_width (1.0);
        ctx.stroke ();
    }
}
