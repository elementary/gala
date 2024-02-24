/*
 * Copyright 2021 José Expósito <jose.exposito89@gmail.com>
 * Copyright 2021-2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * Clutter actor to display text in a tooltip-like component.
 */
public class Gala.Tooltip : CanvasActor {
    private static Clutter.Color text_color;
    private static Gtk.Border padding;
    private static Gtk.StyleContext style_context;

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

    construct {
        text = "";
        max_width = 200;

        resize ();
    }

    private static void create_gtk_objects () {
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

        var text_rgba = (Gdk.RGBA) label_style_context.get_property (
             Gtk.STYLE_PROPERTY_COLOR,
             Gtk.StateFlags.NORMAL
         );

        text_color = Clutter.Color () {
            red = (uint8) text_rgba.red * uint8.MAX,
            green = (uint8) text_rgba.green * uint8.MAX,
            blue = (uint8) text_rgba.blue * uint8.MAX,
            alpha = (uint8) text_rgba.alpha * uint8.MAX,
        };
    }

    public void set_text (string new_text, bool redraw = true) {
        text = new_text;

        if (redraw) {
            resize ();
        }
    }

    public void set_max_width (float new_max_width, bool redraw = true) {
        max_width = new_max_width;

        if (redraw) {
            resize ();
        }
    }

    private void resize () {
        visible = (text.length != 0);

        if (!visible) {
            return;
        }

        // First set the text
        if (text_actor != null) {
            remove_child (text_actor);
        }

        text_actor = new Clutter.Text () {
            color = text_color,
            x = padding.left,
            y = padding.top,
            ellipsize = Pango.EllipsizeMode.MIDDLE
        };
        text_actor.text = text;

        if ((text_actor.width + padding.left + padding.right) > max_width) {
            text_actor.width = max_width - padding.left - padding.right;
        }

        add_child (text_actor);

        // Adjust the size of the tooltip to the text
        width = text_actor.width + padding.left + padding.right;
        height = text_actor.height + padding.top + padding.bottom;

        //Failsafe that if by accident the size doesn't change we still redraw
        content.invalidate ();
    }

    protected override void draw (Cairo.Context ctx, int width, int height) {
        if (style_context == null) {
            create_gtk_objects ();
        }

        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();
        ctx.set_operator (Cairo.Operator.OVER);

        style_context.render_background (ctx, 0, 0, width, height);

        ctx.restore ();
    }
}
