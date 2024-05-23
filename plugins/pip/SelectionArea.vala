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

public class Gala.Plugins.PIP.SelectionArea : CanvasActor {
    public signal void captured (int x, int y, int width, int height);
    public signal void selected (int x, int y);
    public signal void closed ();

    public Gala.WindowManager wm { get; construct; }

    private Gala.ModalProxy? modal_proxy;
    private Gdk.Point start_point;
    private Gdk.Point end_point;
    private bool dragging = false;
    private bool clicked = false;

    public SelectionArea (Gala.WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        start_point = { 0, 0 };
        end_point = { 0, 0 };
        visible = true;
        reactive = true;

        int screen_width, screen_height;
        wm.get_display ().get_size (out screen_width, out screen_height);
        width = screen_width;
        height = screen_height;
    }

#if HAS_MUTTER45
    public override bool key_press_event (Clutter.Event e) {
#else
    public override bool key_press_event (Clutter.KeyEvent e) {
#endif
        if (e.get_key_symbol () == Clutter.Key.Escape) {
            close ();
            closed ();
            return true;
        }

        return false;
    }

#if HAS_MUTTER45
    public override bool button_press_event (Clutter.Event e) {
#else
    public override bool button_press_event (Clutter.ButtonEvent e) {
#endif
        if (dragging || e.get_button () != Clutter.Button.PRIMARY) {
            return true;
        }

        clicked = true;

        float press_x, press_y;
        e.get_coords (out press_x, out press_y);
        start_point = { (int) press_x, (int) press_y};

        return true;
    }

#if HAS_MUTTER45
    public override bool button_release_event (Clutter.Event e) {
#else
    public override bool button_release_event (Clutter.ButtonEvent e) {
#endif
        if (e.get_button () != Clutter.Button.PRIMARY) {
            return true;
        }

        if (!dragging) {
            float event_x, event_y;
            e.get_coords (out event_x, out event_y);
            selected ((int) event_x, (int) event_y);
            close ();
            return true;
        }

        dragging = false;
        clicked = false;

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

#if HAS_MUTTER45
    public override bool motion_event (Clutter.Event e) {
#else
    public override bool motion_event (Clutter.MotionEvent e) {
#endif
        if (!clicked) {
            return true;
        }

        float press_x, press_y;
        e.get_coords (out press_x, out press_y);
        end_point = { (int) press_x, (int) press_y};
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

    private void get_selection_rectangle (out int x, out int y, out int width, out int height) {
        x = int.min (start_point.x, end_point.x);
        y = int.min (start_point.y, end_point.y);
        width = (start_point.x - end_point.x).abs ();
        height = (start_point.y - end_point.y).abs ();
    }

    protected override void draw (Cairo.Context ctx, int width, int height) {
        ctx.save ();

        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();

        ctx.restore ();

        if (!dragging) {
            return;
        }

        int x, y, w, h;
        get_selection_rectangle (out x, out y, out w, out h);

        ctx.rectangle (x, y, w, h);
        ctx.set_source_rgba (0.1, 0.1, 0.1, 0.2);
        ctx.fill ();

        ctx.rectangle (x, y, w, h);
        ctx.set_source_rgb (0.7, 0.7, 0.7);
        ctx.set_line_width (1.0);
        ctx.stroke ();
    }
}
