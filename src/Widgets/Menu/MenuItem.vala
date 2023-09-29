/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.MenuItem : Clutter.Actor {
    public signal void activated ();

    private const int WRAPPER_BORDER_RADIUS = 3;
    private const string CAPTION_FONT_NAME = "Inter";

    private Clutter.Text text;
    private Clutter.Canvas canvas;

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

        if (Granite.Settings.get_default ().prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
            text_color = "#fafafa";
        }

        var widget = new Gtk.Grid ();

        var pango_context = widget.create_pango_context ();
        var font_desc = pango_context.get_font_description ();

        text = new Clutter.Text.with_text (null, "Hello World!") {
            color = Clutter.Color.from_string (text_color),
            font_description = font_desc
        };
        text.set_pivot_point (0.5f, 0.5f);
        text.set_ellipsize (Pango.EllipsizeMode.END);
        text.set_line_alignment (Pango.Alignment.CENTER);

        canvas = new Clutter.Canvas ();
        canvas.draw.connect (draw_background);

        reactive = true;
        add_child (text);
        set_content (canvas);

        this.scale_factor = scale_factor;
    }

    public override bool enter_event (Clutter.CrossingEvent event) {
        selected = true;
        return false;
    }

    public override bool leave_event (Clutter.CrossingEvent event) {
        selected = false;
        return false;
    }

    public override bool button_release_event (Clutter.ButtonEvent event) {
        if (event.button == Clutter.Button.PRIMARY) {
            activated ();
            return true;
        }

        return false;
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
            var rgba = InternalUtils.get_foreground_color ();
            ctx.set_source_rgba (rgba.red, rgba.green, rgba.blue, 0.15);
            ctx.rectangle (0, 0, width, height);
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.fill ();

            ctx.restore ();
        }

        return true;
    }
}
