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
    const int PIE_SIZE = 20;
    const int PIE_WIDTH = 8;
    const double MENU_RADIUS = 4.0 * PIE_SIZE;

    public WindowManager wm { get; construct; }
    private Meta.Display display;
    private ModalProxy? modal_proxy;
    private Clutter.Canvas canvas;
    private int start_x;
    private int start_y;
    private int distance_x;
    private int distance_y;
    public string[] options = {"Tile Right", "Tile Bottom Right", "Tile Bottom", "Tile Bottom Left", "Tile Left", "Tile Top Left", "Tile Top", "Tile Top Right"};
    public int? selected;

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

        canvas = new Clutter.Canvas ();
        canvas.set_size (screen_width, screen_height);
        canvas.draw.connect (draw_pie_menu);
        set_content (canvas);
        canvas.invalidate ();
    }

    public bool is_opened () {
        return visible;
    }

    public void open (HashTable<string,Variant>? hints = null) {
        int x, y;
        display.get_cursor_tracker ().get_pointer (out x, out y, null);
        selected = -1;
        start_x = x;
        start_y = y;
        distance_x = 0;
        distance_y = 0;

        visible = true;
        grab_key_focus ();
        modal_proxy = wm.push_modal ();
        modal_proxy.keybinding_filter = binding => binding.get_name () != "pie-menu";
        content.invalidate ();
    }

    public void close () {
        visible = false;
        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
        }
    }

    public override bool key_press_event (Clutter.KeyEvent e) {
        if (e.keyval == Clutter.Key.Escape) {
            close ();
            return true;
        }

        content.invalidate ();
        return false;
    }


    //  public override bool key_release_event (Clutter.KeyEvent e) {
    //      close ();
    //      return true;
    //  }


    public override bool motion_event (Clutter.MotionEvent e) {
        distance_x = (int) e.x - start_x;
        distance_y = (int) e.y - start_y;
        content.invalidate ();
        return true;
    }

    private bool draw_pie_menu (Cairo.Context ctx) {
        Clutter.cairo_clear (ctx);
        ctx.arc (start_x, start_y, PIE_SIZE - PIE_WIDTH / 2, 0, 2 * Math.PI);
        ctx.set_source_rgba (1.0, 1.0, 1.0, 1.0);
        ctx.set_line_width (PIE_WIDTH);
        ctx.stroke ();
        ctx.arc (start_x, start_y, PIE_SIZE - PIE_WIDTH / 2 + 4, 0, 2 * Math.PI);
        ctx.set_source_rgb (0.4, 0.4, 0.4);
        ctx.set_line_width (0.25);
        ctx.stroke ();
        ctx.arc (start_x, start_y, PIE_SIZE - PIE_WIDTH / 2 - 4, 0, 2 * Math.PI);
        ctx.stroke ();

        int n_options = options.length;
        double phi = Math.atan2((double) distance_y, (double) distance_x);
        double step = 2 * Math.PI / n_options;
        double p = (double) n_options / 2;
        double radius = 6.0;
        double height = 24.0;
        int distance_2 = distance_x * distance_x + distance_y * distance_y;
        if (distance_2 > PIE_SIZE * PIE_SIZE)
            selected =  (int) Math.round((2 * Math.PI + phi) * n_options / 2 / Math.PI) % n_options;
        else {
            selected = -1;
        }
        debug(@"selected $selected");
        for (int i = 0; i < n_options; i++) {
            ctx.set_font_size (12.0);
            Cairo.TextExtents extents;
            ctx.text_extents (options[i], out extents);
            double width = extents.width + 16.0;
            double angle = i * step;
            double offset_x = Math.cos (angle);
            double offset_y = Math.sin (angle);
            double offset_sign_x = (offset_x > 0.01 ? 1 : 0) - ((offset_x < -0.01) ? 1 : 0) - 1;
            double offset_sign_y = (offset_y > 0.99 ? 1 : 0) - ((offset_y < -0.99) ? 1 : 0) - 1;
            double x = Math.round(start_x + offset_x * MENU_RADIUS + offset_sign_x * width / 2.0);
            //  double y = Math.round(start_y + (MENU_RADIUS + height / 2.0) * (2.0 * (Math.fabs((i + 3.0 * p / 2.0) % (2.0 * p) - p) / p ) - 1) - height / 2);
            double y = Math.round(start_y + offset_y * MENU_RADIUS + offset_sign_y * height / 2.0);
            double degrees = Math.PI / 180.0;

            ctx.new_sub_path ();
            ctx.arc (x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees);
            ctx.arc (x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees);
            ctx.arc (x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees);
            ctx.arc (x + radius, y + radius, radius, 180 * degrees, 270 * degrees);
            ctx.close_path ();
            if (i == selected) {
                ctx.set_source_rgb (0.549, 0.835, 1);
            } else {
                ctx.set_source_rgb (1.0, 1.0, 1.0);
            }
            ctx.fill_preserve ();

            if (i == selected) {
                ctx.set_source_rgb (0, 0.180, 0.6);
            } else {
                ctx.set_source_rgb (0.4, 0.4, 0.4);
            }
            ctx.set_line_width (0.25);
            ctx.stroke ();

            ctx.set_source_rgb (0.102, 0.102, 0.102);
            ctx.select_font_face("Inter", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            ctx.move_to (x + width / 2 - (extents.width / 2 + extents.x_bearing),
                         y + height / 2 - (extents.height / 2 + extents.y_bearing));
            ctx.show_text (options[i]);

            ctx.arc (start_x + offset_x * MENU_RADIUS, start_y + offset_y * MENU_RADIUS, 4, 0, 2 * Math.PI);
            ctx.set_source_rgba (0.0, 1.0, 1.0, 1.0);
            ctx.fill ();
        }

        ctx.arc (start_x, start_y, MENU_RADIUS, 0, 2 * Math.PI);
        ctx.set_source_rgba (0.0, 0.0, 1.0, 1.0);
        ctx.set_line_width (2);
        ctx.stroke ();

        if (distance_2 > PIE_SIZE * PIE_SIZE) {
            double tmp = Math.PI / 8;
            ctx.stroke ();
            ctx.arc (start_x, start_y, PIE_SIZE - PIE_WIDTH / 2, phi - tmp, phi + tmp);
            ctx.set_source_rgb (0.549, 0.835, 1);
            ctx.set_line_width (PIE_WIDTH);
            ctx.stroke ();

            //  int i = (int) Math.round(phi * n_options / 2 / Math.PI);
            //  selected = i;
            //  double angle = i * step;
            //  double offset_x = 5 * PIE_SIZE * Math.cos (angle);
            //  double offset_sign_x = (offset_x > 0.01 ? 1 : 0) - ((offset_x < -0.01) ? 1 : 0) - 1;
            //  ctx.rectangle (
            //      start_x + offset_x + offset_sign_x * width / 2.0,
            //      start_y + (5 * PIE_SIZE + height / 2.0) * (2.0 * (Math.fabs((i + 3.0 * p / 2.0) % (2.0 * p) - p) / p ) - 1) - height / 2,
            //      width,
            //      height
            //  );
            //  ctx.set_source_rgb (0.549, 0.835, 1);
            //  ctx.fill ();
        }

        return true;
    }
}
