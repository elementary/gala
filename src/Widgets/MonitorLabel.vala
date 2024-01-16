/*
 * Copyright 2024 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.MonitorLabel : Clutter.Actor {
    private const string provider_template = """
    @define-color BG_COLOR %s;
    """;
    private const string CAPTION_FONT_NAME = "Inter";
    private const int SPACING = 12;

    public Meta.Display display { get; construct; }
    public MonitorLabelInfo label_info { get; construct; }

    private Gtk.WidgetPath widget_path;
    private Gtk.StyleContext style_context;
    private Clutter.Canvas canvas;
    private float scaling_factor = 1.0f;

    public MonitorLabel (Meta.Display display, MonitorLabelInfo label_info) {
        Object (
            display: display,
            label_info: label_info
        );
    }

    construct {
        scaling_factor = display.get_monitor_scale (label_info.monitor);

        canvas = new Clutter.Canvas ();
        canvas.scale_factor = scaling_factor;
        set_content (canvas);

        create_components ();

        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (() => {
            var current_scale = display.get_monitor_scale (label_info.monitor);
            if (current_scale != scaling_factor) {
                scaling_factor = current_scale;
                canvas.scale_factor = scaling_factor;
                create_components ();
            }
        });

        canvas.draw.connect (draw);
    }

    private bool draw (Cairo.Context ctx, int width, int height) {
        if (style_context == null) { // gtk is not initialized yet
            create_gtk_objects ();
        }

        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();

        ctx.set_operator (Cairo.Operator.OVER);
        style_context.render_background (ctx, 0, 0, width, height);
        style_context.render_frame (ctx, 0, 0, width, height);
        ctx.restore ();

        return true;
    }

    private void create_components () {
        var label = new Clutter.Text.full (
            CAPTION_FONT_NAME,
            label_info.label,
            Clutter.Color.from_string (label_info.text_color)
        );

        add_child (label);

        var monitor_geometry = display.get_monitor_geometry (label_info.monitor);
        x = monitor_geometry.x + SPACING;
        y = monitor_geometry.y + SPACING;
    }

    private void create_gtk_objects () {
        widget_path = new Gtk.WidgetPath ();
        widget_path.append_type (typeof (Gtk.Window));
        widget_path.iter_set_object_name (-1, "window");

        style_context = new Gtk.StyleContext ();
        style_context.set_scale ((int) Math.round (scaling_factor));
        style_context.set_path (widget_path);
        style_context.add_class ("background");
        style_context.add_class ("csd");
        style_context.add_class ("unified");

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (provider_template.printf (label_info.background_color));
        } catch (Error e) {
            critical (e.message);
        }
        style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
}
