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
 */
public class Gala.Tooltip : Clutter.Actor {
    private static Gdk.RGBA text_color;
    private static Gdk.RGBA bg_color;
    private static Gtk.Border padding;
    private static int border_radius;

    /**
     * Canvas to draw the Tooltip background.
     */
    private Clutter.Canvas background_canvas;

    /**
     * Actor to display the Tooltip text.
     */
    private Clutter.Text? text_actor = null;

    /**
     * Maximum width of the Tooltip.
     * @see set_max_width
     */
    public float max_width;

    static construct {
        var tooltip_widget_path = new Gtk.WidgetPath ();
        var pos = tooltip_widget_path.append_type (typeof (Gtk.Window));
        tooltip_widget_path.iter_set_object_name (pos, "tooltip");
        tooltip_widget_path.iter_add_class (pos, Gtk.STYLE_CLASS_CSD);
        tooltip_widget_path.iter_add_class (pos, Gtk.STYLE_CLASS_BACKGROUND);

        var tooltip_style_context = new Gtk.StyleContext ();
        tooltip_style_context.set_path (tooltip_widget_path);

        tooltip_widget_path.append_type (typeof (Gtk.Label));

        var label_style_context = new Gtk.StyleContext ();
        label_style_context.set_path (tooltip_widget_path);

        bg_color = (Gdk.RGBA) tooltip_style_context.get_property (
            Gtk.STYLE_PROPERTY_BACKGROUND_COLOR,
            Gtk.StateFlags.NORMAL
        );

        text_color = (Gdk.RGBA) label_style_context.get_property (
            Gtk.STYLE_PROPERTY_COLOR,
            Gtk.StateFlags.NORMAL
        );

        border_radius = (int) tooltip_style_context.get_property (
            Gtk.STYLE_PROPERTY_BORDER_RADIUS,
            Gtk.StateFlags.NORMAL
        );

        padding = tooltip_style_context.get_padding (Gtk.StateFlags.NORMAL);
    }

    construct {
        max_width = 200;

        background_canvas = new Clutter.Canvas ();
        background_canvas.draw.connect (draw_background);
        content = background_canvas;
        text_actor = new Clutter.Text () {
            color = Clutter.Color () {
                red = (uint8) text_color.red * uint8.MAX,
                green = (uint8) text_color.green * uint8.MAX,
                blue = (uint8) text_color.blue * uint8.MAX,
                alpha = (uint8) text_color.alpha * uint8.MAX,
            },
            x = padding.left,
            y = padding.top,
            ellipsize = Pango.EllipsizeMode.MIDDLE
        };

        add_child (text_actor);
        draw ();
    }

    public void set_text (string new_text, bool redraw = true) {
        text_actor.text = new_text;

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
        visible = (text_actor.text.length != 0);

        if (!visible) {
            return;
        }

        if ((text_actor.width + padding.left + padding.right) > max_width) {
            text_actor.width = max_width - padding.left - padding.right;
        }

        // Adjust the size of the tooltip to the text
        width = text_actor.width + padding.left + padding.right;
        height = text_actor.height + padding.top + padding.bottom;
        background_canvas.set_size ((int) width, (int) height);

        // And paint the background
        background_canvas.invalidate ();
    }

    private static bool draw_background (Cairo.Context cr, int width, int height) {
        cr.save ();
        cr.set_operator (Cairo.Operator.CLEAR);
        cr.paint ();
        cr.restore ();

        Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 0, 0, width, height, border_radius);
        cr.set_source_rgba (bg_color.red, bg_color.green, bg_color.blue, bg_color.alpha);
        cr.fill ();

        return false;
    }
}
