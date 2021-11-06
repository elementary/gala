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
    private static Gtk.Border padding;
    private static Gtk.StyleContext style_context;

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
        var tooltip_widget_path = new Gtk.WidgetPath ();
        var pos = tooltip_widget_path.append_type (typeof (Gtk.Window));
        tooltip_widget_path.iter_set_object_name (pos, "tooltip");
        tooltip_widget_path.iter_add_class (pos, Gtk.STYLE_CLASS_CSD);
        tooltip_widget_path.iter_add_class (pos, Gtk.STYLE_CLASS_BACKGROUND);

        style_context = new Gtk.StyleContext ();
        style_context.set_path (tooltip_widget_path);

        padding = style_context.get_padding (Gtk.StateFlags.NORMAL);

        tooltip_widget_path.append_type (typeof (Gtk.Label));

        var label_style_context = new Gtk.StyleContext ();
        label_style_context.set_path (tooltip_widget_path);

        text_color = (Gdk.RGBA) label_style_context.get_property (
             Gtk.STYLE_PROPERTY_COLOR,
             Gtk.StateFlags.NORMAL
         );
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
        if (text_actor != null) {
            remove_child (text_actor);
        }

        text_actor = new Clutter.Text () {
            color = Clutter.Color () {
                red = (uint8) text_color.red * uint8.MAX,
                green = (uint8) text_color.green * uint8.MAX,
                blue = (uint8) text_color.blue * uint8.MAX,
                alpha = (uint8) text_color.alpha * uint8.MAX,
            },
            x = padding.left,
            y = padding.top,
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            use_markup = true
        };
        text_actor.set_markup (Markup.printf_escaped ("<span size='large'>%s</span>", text));

        if ((text_actor.width + padding.left + padding.right) > max_width) {
            text_actor.width = max_width - padding.left - padding.right;
        }

        add_child (text_actor);

        // Adjust the size of the tooltip to the text
        width = text_actor.width + padding.left + padding.right;
        height = text_actor.height + padding.top + padding.bottom;
        background_canvas.set_size ((int) width, (int) height);

        // And paint the background
        background_canvas.invalidate ();
    }

    private static bool draw_background (Cairo.Context ctx, int width, int height) {
        ctx.save ();

        style_context.render_background (ctx, 0, 0, width, height);
        style_context.render_frame (ctx, 0, 0, width, height);

        ctx.restore ();

        return false;
    }
}
