/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.MenuItem : Clutter.Actor {
    public signal void activated ();

    private Clutter.Text text;

    private bool _selected = false;
    public bool selected {
        get {
            return _selected;
        }
        set {
            _selected = value;
            if (_selected) {
                var rgba = InternalUtils.get_foreground_color ();
                Clutter.Color foreground_color = {
                    (uint8) (rgba.red * 255),
                    (uint8) (rgba.green * 255),
                    (uint8) (rgba.blue * 255),
                    (uint8) (0.15 * 255)
                };
                set_background_color (foreground_color);
            } else {
                set_background_color (null);
            }
        }
    }

    public MenuItem (string label) {
        var text_color = "#2e2e31";

        if (Granite.Settings.get_default ().prefers_color_scheme == DARK) {
            text_color = "#fafafa";
        }

        var widget = new Gtk.Grid ();

        var pango_context = widget.create_pango_context ();
        var font_desc = pango_context.get_font_description ();

        text = new Clutter.Text.with_text (null, label) {
            color = Clutter.Color.from_string (text_color),
            font_description = font_desc,
            margin_left = 24,
            margin_right = 24,
            margin_top = 6,
            margin_bottom = 6,
            ellipsize = END
        };
        text.set_pivot_point (0.5f, 0.5f);
        text.set_line_alignment (Pango.Alignment.CENTER);

        min_width = 150;
        reactive = true;
        add_child (text);
    }

    public void scale (float scale_factor) {
        text.margin_left = text.margin_right = InternalUtils.scale_to_int (24, scale_factor);
        text.margin_top = text.margin_bottom = InternalUtils.scale_to_int (6, scale_factor);
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
}
