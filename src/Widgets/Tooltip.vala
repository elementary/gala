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
 * Clutter actor to display text in a tooltip-like component.
 *
 * Style constants from:
 * https://github.com/elementary/stylesheet/blob/master/src/widgets/_tooltips.scss
 */
public class Gala.Tooltip : Clutter.Actor {
    private static double background_color;
    private static double background_opacity;
    private static double background_border_radius;
    private static Clutter.Color text_color;
    private static int padding_top;
    private static int padding_bottom;
    private static int padding_left;
    private static int padding_right;

    /**
     * Canvas to draw the Tooltip background.
     */
    private Clutter.Canvas background_canvas;

    /**
     * Actor to display the Tooltip text.
     */
    private Clutter.Text? text_actor = null;

    /**
     * Text displayed in the Tooltip.
     * @see set_text
     */
    private string text;

    /**
     * Maximum width of the Tooltip.
     * @see set_max_width
     */
    public float max_width;

    static construct {
        var scale = InternalUtils.get_ui_scaling_factor ();

        background_color = (26 / 255); // #1a
        background_opacity = 0.9;
        background_border_radius = 3 * scale;
        text_color = Clutter.Color.from_string ("#ffffff");
        padding_top = 3 * scale;
        padding_bottom = 3 * scale;
        padding_left = 6 * scale;
        padding_right = 6 * scale;
    }

    construct {
        text = "";
        max_width = 200;

        background_canvas = new Clutter.Canvas ();
        background_canvas.draw.connect (draw_background);
        content = background_canvas;

        draw ();
    }

    public void set_text (string new_text, bool redraw = true) {
        text = new_text;

        if (redraw) {
            draw ();
        }
    }

    public void set_max_width (float new_max_width, bool redraw = true) {
        max_width = new_max_width;

        if (redraw) {
            draw ();
        }
    }

    private void draw () {
        visible = (text.length != 0);

        if (!visible) {
            return;
        }

        // First set the text
        remove_child (text_actor);

        text_actor = new Clutter.Text () {
            color = text_color,
            x = padding_left,
            y = padding_top,
            ellipsize = Pango.EllipsizeMode.END,
            use_markup = true
        };
        text_actor.set_markup (Markup.printf_escaped ("<span size='large'>%s</span>", text));

        if ((text_actor.width + padding_left + padding_right) > max_width) {
            text_actor.width = max_width - padding_left - padding_right;
        }

        add_child (text_actor);

        // Adjust the size of the tooltip to the text
        width = text_actor.width + padding_left + padding_right;
        height = text_actor.height + padding_top + padding_bottom;
        background_canvas.set_size ((int) width, (int) height);

        // And paint the background
        background_canvas.invalidate ();
    }

    private bool draw_background (Cairo.Context cr, int width, int height) {
        cr.save ();
        cr.set_operator (Cairo.Operator.CLEAR);
        cr.paint ();
        cr.restore ();

        Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 0, 0, width, height, background_border_radius);
        cr.set_source_rgba (background_color, background_color, background_color, background_opacity);
        cr.fill ();

        return false;
    }
}
