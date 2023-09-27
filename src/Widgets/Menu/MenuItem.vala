/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.MenuItem : Clutter.Actor {
    private const int WRAPPER_BORDER_RADIUS = 3;
    private const string CAPTION_FONT_NAME = "Inter";

    private Clutter.Text text;
    private Clutter.Canvas canvas;

    private Granite.Settings granite_settings;

    private bool _selected = false;
    public bool selected {
        get {
            return _selected;
        }
        set {
            _selected = value;
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

        canvas = new Clutter.Canvas ();
        canvas.draw.connect (draw_background);
        set_content (canvas);

        this.scale_factor = scale_factor;
    }

    private void update_size () {
        set_size (text.width, text.height);
        canvas.set_size ((int) text.width, (int) text.height);
    }

    private bool draw_background (Cairo.Context ctx, int width, int height) {
        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();

        if (selected) {
            var rgba = InternalUtils.get_theme_accent_color ();
            Clutter.Color accent_color = {
                (uint8) (rgba.red * 255),
                (uint8) (rgba.green * 255),
                (uint8) (rgba.blue * 255),
                (uint8) (rgba.alpha * 255)
            };

            var rect_radius = InternalUtils.scale_to_int (WRAPPER_BORDER_RADIUS, scale_factor);

            // draw rect
            Clutter.cairo_set_source_color (ctx, accent_color);
            Drawing.Utilities.cairo_rounded_rectangle (ctx, 0, 0, width, height, rect_radius);
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.fill ();

            ctx.restore ();
        }

        return true;
    }
}
