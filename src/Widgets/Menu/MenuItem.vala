/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.MenuItem : Clutter.Actor {
    private const int WRAPPER_BORDER_RADIUS = 3;
    private const string CAPTION_FONT_NAME = "Inter";

    private Clutter.Text text;
    private Clutter.Canvas canvas;
    private Gtk.StyleContext style_context;

    private Granite.Settings granite_settings;

    private bool _selected = false;
    public bool selected {
        get {
            return _selected;
        }
        set {
            _selected = value;
            if (value) {
                // style_context.set_state (Gtk.StateFlags.FOCUSED);
                warning ("SELECTED");
            } else {
                // style_context.set_state (Gtk.StateFlags.NORMAL);
                warning ("NOT ANYMORE");
            }
            canvas.invalidate ();
        }
    }

    private float _scale_factor = 1.0f;
    public float scale_factor {
        get {
            return _scale_factor;
        }
        set {
            _scale_factor = value;
            canvas.scale_factor = _scale_factor;

            update_size ();
            canvas.invalidate ();
        }
    }

    public MenuItem (string label, float scale_factor) {
        var text_color = "#2e2e31";

        if (granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
            text_color = "#fafafa";
        }

        text = new Clutter.Text.full (CAPTION_FONT_NAME, "Hello World!", Clutter.Color.from_string (text_color));
        text.set_pivot_point (0.5f, 0.5f);
        text.set_ellipsize (Pango.EllipsizeMode.END);
        text.set_line_alignment (Pango.Alignment.CENTER);
        add_child (text);
        var window = new Gtk.Window ();

        style_context = window.get_style_context ();
        style_context.add_class ("csd");
        style_context.add_class ("unified");
        style_context.add_class (Gtk.STYLE_CLASS_MENUITEM);

        canvas = new Clutter.Canvas ();
        canvas.draw.connect (draw_background);
        set_content (canvas);

        this.scale_factor = scale_factor;
    }

    // public override bool enter_event (Clutter.CrossingEvent event) {
    //     selected = true;
    //     warning ("SELECTED");
    //     return base.enter_event (event);
    // }

    // public override bool leave_event (Clutter.CrossingEvent event) {
    //     selected = false;
    //     warning ("NOT SELECTED");
    //     return base.leave_event (event);
    // }

    private void update_size () {
        set_size (text.width, text.height);
        // canvas.set_size ((int) text.width, (int) text.height);
        canvas.set_size ((int) 50, (int) 50);
    }

    private bool draw_background (Cairo.Context ctx, int width, int height) {
        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();

        // if (granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
        // unowned var gtksettings = Gtk.Settings.get_default ();
        // var dark_style_provider = Gtk.CssProvider.get_named (gtksettings.gtk_theme_name, "dark");
        // style_context.add_provider (dark_style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        // } else if (dark_style_provider != null) {
        //     style_context.remove_provider (dark_style_provider);
        //     dark_style_provider = null;
        // }

        // ctx.set_operator (Cairo.Operator.OVER);
        // style_context.render_background (ctx, 0, 0, width, height);
        // warning ("RENDER BACKGROUND");

        if (selected) {
            var rgba = InternalUtils.get_foreground_color ();
            ctx.set_source_rgba (rgba.red, rgba.green, rgba.blue, 0.15);
            ctx.rectangle (0, 0, width, height);
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.fill ();

            ctx.restore ();
        }
        // style_context.render_frame (ctx, 0, 0, width, height);
        // ctx.restore ();

        // if (selected) {
        //     var rgba = InternalUtils.get_theme_accent_color ();
        //     Clutter.Color accent_color = {
        //         (uint8) (rgba.red * 255),
        //         (uint8) (rgba.green * 255),
        //         (uint8) (rgba.blue * 255),
        //         (uint8) (rgba.alpha * 255)
        //     };

        //     var rect_radius = InternalUtils.scale_to_int (WRAPPER_BORDER_RADIUS, scale_factor);

        //     // draw rect
        //     Clutter.cairo_set_source_color (ctx, accent_color);
        //     Drawing.Utilities.cairo_rounded_rectangle (ctx, 0, 0, width, height, rect_radius);
        //     ctx.set_operator (Cairo.Operator.SOURCE);
        //     ctx.fill ();

        //     ctx.restore ();
        // }

        return true;
    }
}
