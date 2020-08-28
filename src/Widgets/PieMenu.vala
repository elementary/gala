/*
* Copyright 2020 Felix Andreas
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
*/

public class Gala.PieMenu : Clutter.Actor, ActivatableComponent {
    public signal void closed ();

    private const int PIE_SIZE = 20;
    private const int PIE_WIDTH = 8;
    private const double MENU_RADIUS = 4.0 * PIE_SIZE;
    private const double HEIGHT = 24.0;
    private const double BACKGROUND_OPACITY = 0.7;
    private Cairo.Pattern accent_color;
    private Cairo.Pattern accent_color_light;
    private Cairo.Pattern white = new Cairo.Pattern.rgb (1.0, 1.0, 1.0);
    private Cairo.Pattern silver_300 = new Cairo.Pattern.rgb (0.831, 0.831, 0.831);
    private Cairo.Pattern black_700 = new Cairo.Pattern.rgb (0.102, 0.102, 0.102);

    public WindowManager wm { get; construct; }
    private Meta.Display display;
    private ModalProxy? modal_proxy;
    private Clutter.Canvas canvas;
    public string[] options;
    public int selected = -1;
    private int start_x;
    private int start_y;
    private double phi;
    private Granite.Drawing.BufferSurface buffer;

    public PieMenu (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        visible = false;
        reactive = true;
        display = wm.get_display ();
        int screen_width, screen_height;
        display.get_size (out screen_width, out screen_height);
        width = screen_width;
        height = screen_height;
        buffer = new Granite.Drawing.BufferSurface (screen_width, screen_height);
        canvas = new Clutter.Canvas ();
        canvas.set_size (screen_width, screen_height);
        //  canvas.draw.connect (draw_pie_menu_highlight);
        canvas.draw.connect (draw_pie_menu_highlight);
        set_content (canvas);
        canvas.invalidate ();
        //  draw_pie_menu (canvas);
    }

    public bool is_opened () {
        return visible;
    }

    public void open (HashTable<string,Variant>? hints = null) {
        if (is_opened ()) {
            close ();
            return;
        }

        var rgba = InternalUtils.get_theme_accent_color ();
        accent_color = new Cairo.Pattern.rgb (rgba.red, rgba.green, rgba.blue);
        accent_color_light = new Cairo.Pattern.rgba (rgba.red, rgba.green, rgba.blue, BACKGROUND_OPACITY);

        int x, y;
        display.get_cursor_tracker ().get_pointer (out x, out y, null);
        selected = -1;
        start_x = x;
        start_y = y;
        phi = 0;

        visible = true;
        grab_key_focus ();
        modal_proxy = wm.push_modal ();
        draw_pie_menu (buffer.context);
        content.invalidate ();
    }

    public void close () {
        visible = false;
        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
        }

        closed ();
    }

    public override bool key_press_event (Clutter.KeyEvent e) {
        if (e.keyval == Clutter.Key.Escape) {
            close ();
        }

        return false;
    }


    public override bool key_release_event (Clutter.KeyEvent e) {
        close ();
        return true;
    }


    public override bool motion_event (Clutter.MotionEvent e) {
        var distance_x = (int) e.x - start_x;
        var distance_y = (int) e.y - start_y;
        phi = Math.atan2((double) distance_y, (double) distance_x);
        if (distance_x * distance_x + distance_y * distance_y > PIE_SIZE * PIE_SIZE) {
            var n_options = options.length;
            selected = (int) Math.round((1 + phi / Math.PI) * n_options / 2) % n_options;
        } else {
            selected = -1;
        }

        canvas.invalidate ();
        return true;
    }

    private bool draw_pie_menu (Cairo.Context ctx) {
        Clutter.cairo_clear (ctx);

        ctx.stroke ();
        ctx.set_source (white);
        ctx.set_line_width (PIE_WIDTH);
        ctx.arc (start_x, start_y, PIE_SIZE - PIE_WIDTH / 2, 0, 2 * Math.PI);
        ctx.stroke ();

        ctx.set_source (silver_300);
        ctx.set_line_width (1.0);
        ctx.arc (start_x, start_y, PIE_SIZE - PIE_WIDTH / 2 + 4, 0, 2 * Math.PI);
        ctx.stroke ();
        ctx.arc (start_x, start_y, PIE_SIZE - PIE_WIDTH / 2 - 4, 0, 2 * Math.PI);
        ctx.stroke ();

        double step = 2 * Math.PI / options.length;
        ctx.select_font_face("Inter", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        ctx.set_font_size (12.0);
        for (int i = 0; i < options.length; i++) {
            Cairo.TextExtents extents;
            ctx.text_extents (options[i], out extents);
            double width = extents.width + 16.0;
            double angle = i * step + Math.PI;
            double offset_x = Math.cos (angle);
            double offset_y = Math.sin (angle);
            double sign_x = (double) (offset_x > 0.01) - (double) (offset_x < -0.01) - 1.0;
            double sign_y = (double) (offset_y > 0.99) - (double) (offset_y < -0.99) - 1.0;
            double x = Math.round(start_x + offset_x * MENU_RADIUS + sign_x * width / 2.0);
            double y = Math.round(start_y + offset_y * MENU_RADIUS + sign_y * HEIGHT / 2.0);
            Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, x, y, width, HEIGHT, 6.0);
            ctx.set_source (white);
            ctx.fill_preserve ();
            ctx.set_source (black_700);
            ctx.set_line_width (0.25);
            ctx.stroke ();
            ctx.move_to (
                x + width / 2 - (extents.width / 2 + extents.x_bearing),
                y + HEIGHT / 2 - (extents.height / 2 + extents.y_bearing)
            );
            ctx.show_text (options[i]);
        }
        return true;
    }

    private bool draw_pie_menu_highlight (Cairo.Context ctx) {
        Clutter.cairo_clear (ctx);
        ctx.set_source_surface (buffer.surface, 0, 0);
        ctx.paint ();

        if (selected == -1) {
            return true;
        }

        double step = 2 * Math.PI / options.length;
        ctx.select_font_face("Inter", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        ctx.set_font_size (12.0);
        Cairo.TextExtents extents;
        ctx.text_extents (options[selected], out extents);
        double width = extents.width + 16.0;
        double angle = selected * step + Math.PI;
        double offset_x = Math.cos (angle);
        double offset_y = Math.sin (angle);
        double sign_x = (double) (offset_x > 0.01) - (double) (offset_x < -0.01) - 1.0;
        double sign_y = (double) (offset_y > 0.99) - (double) (offset_y < -0.99) - 1.0;
        double x = Math.round(start_x + offset_x * MENU_RADIUS + sign_x * width / 2.0);
        double y = Math.round(start_y + offset_y * MENU_RADIUS + sign_y * HEIGHT / 2.0);
        Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, x, y, width, HEIGHT, 6.0);
        ctx.set_source (accent_color_light);
        ctx.fill_preserve ();
        ctx.set_source (accent_color);
        ctx.set_line_width (0.25);
        ctx.stroke ();
        ctx.set_source (black_700);
        ctx.move_to (
            x + width / 2 - (extents.width / 2 + extents.x_bearing),
            y + HEIGHT / 2 - (extents.height / 2 + extents.y_bearing)
        );
        ctx.show_text (options[selected]);

        ctx.stroke ();
        ctx.arc (start_x, start_y, PIE_SIZE - PIE_WIDTH / 2, phi -  Math.PI / 8, phi +  Math.PI / 8);
        ctx.set_source (accent_color);
        ctx.set_line_width (PIE_WIDTH);
        ctx.stroke ();

        return true;
    }
}
