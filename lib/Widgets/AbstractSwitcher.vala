/*
 * Copyright 2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

 /**
  * AbstractSwitcher is an abstract class that draws a "window switcher"-like widget.
  * It sets up required actor structure and handles drawing.
  */
public abstract class Gala.AbstractSwitcher : CanvasActor {
    public const int WRAPPER_PADDING = 12;
    private const int MIN_OFFSET = 64;

    public Clutter.Actor? actor { get { return this; } }
    public WindowManager wm { protected get; construct; }

    protected float monitor_scale { get; set; default = 1.0f; }
    protected Clutter.Actor container { get; private set; }
    protected string caption_text { set { caption.text = value; } }

    private Gala.Text caption;
    private Drawing.StyleManager style_manager;
    private ShadowEffect shadow_effect;
    private BackgroundBlurEffect blur_effect;

    protected AbstractSwitcher (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        style_manager = Drawing.StyleManager.get_instance ();

        container = new Clutter.Actor () {
            reactive = true,
#if HAS_MUTTER46
            layout_manager = new Clutter.FlowLayout (Clutter.Orientation.HORIZONTAL)
#else
            layout_manager = new Clutter.FlowLayout (Clutter.FlowOrientation.HORIZONTAL)
#endif
        };

        container.get_accessible ().accessible_role = LIST;

        caption = new Gala.Text () {
            ellipsize = END,
            line_alignment = CENTER
        };

        add_child (container);
        add_child (caption);

        reactive = true;
        visible = false;
        opacity = 0;
        layout_manager = new Clutter.BoxLayout () {
            orientation = VERTICAL
        };

        notify["monitor-scale"].connect (scale);
        scale ();

        shadow_effect = new ShadowEffect ("window-switcher", monitor_scale) {
            border_radius = 10,
            shadow_opacity = 100
        };
        bind_property ("monitor-scale", shadow_effect, "monitor-scale");
        add_effect (shadow_effect);

        blur_effect = new BackgroundBlurEffect (40, 9, monitor_scale);
        bind_property ("monitor-scale", blur_effect, "monitor-scale");
        add_effect (blur_effect);

        // Redraw the components if the colour scheme changes.
        style_manager.notify["prefers-color-scheme"].connect (content.invalidate);

        notify["opacity"].connect (() => visible = opacity != 0);
    }

    private void scale () {
        var margin = Utils.scale_to_int (WRAPPER_PADDING, monitor_scale);

        container.margin_left = margin;
        container.margin_right = margin;
        container.margin_bottom = margin;
        container.margin_top = margin;

        caption.margin_left = margin;
        caption.margin_right = margin;
        caption.margin_bottom = margin;
    }

    protected override void get_preferred_width (float for_height, out float min_width, out float natural_width) {
        min_width = 0;

        float preferred_nat_width;
        base.get_preferred_width (for_height, null, out preferred_nat_width);

        unowned var display = wm.get_display ();
        var geom = display.get_monitor_geometry (display.get_current_monitor ());

        float container_nat_width;
        container.get_preferred_size (null, null, out container_nat_width, null);

        var max_width = float.min (
            geom.width - Utils.scale_to_int (MIN_OFFSET * 2, monitor_scale), // Don't overflow the monitor
            container_nat_width // Ellipsize the label if it's longer than the icons
        );

        natural_width = float.min (max_width, preferred_nat_width);
    }

    protected override void draw (Cairo.Context ctx, int width, int height) {
        var background_color = Drawing.Color.LIGHT_BACKGROUND;
        var border_color = Drawing.Color.LIGHT_BORDER;
        var caption_color = "#2e2e31";
        var highlight_color = Drawing.Color.LIGHT_HIGHLIGHT;

        if (style_manager.prefers_color_scheme == Drawing.StyleManager.ColorScheme.DARK) {
            background_color = Drawing.Color.DARK_BACKGROUND;
            border_color = Drawing.Color.DARK_BORDER;
            caption_color = "#fafafa";
            highlight_color = Drawing.Color.DARK_HIGHLIGHT;
        }

#if HAS_MUTTER47
        caption.color = Cogl.Color.from_string (caption_color);
#else
        caption.color = Clutter.Color.from_string (caption_color);
#endif

        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();

        ctx.set_operator (Cairo.Operator.SOURCE);

        var stroke_width = Utils.scale_to_int (1, monitor_scale);
        Drawing.Utilities.cairo_rounded_rectangle (
            ctx,
            stroke_width / 2.0, stroke_width / 2.0,
            width - stroke_width, height - stroke_width,
            Utils.scale_to_int (9, monitor_scale)
        );

        ctx.set_source_rgba (
            background_color.red / 255.0,
            background_color.green / 255.0,
            background_color.blue / 255.0,
            0.6
        );
        ctx.fill_preserve ();

        ctx.set_line_width (stroke_width);
        ctx.set_source_rgba (
            border_color.red / 255.0,
            border_color.green / 255.0,
            border_color.blue / 255.0,
            border_color.alpha / 255.0
        );
        ctx.stroke ();
        ctx.restore ();

        Drawing.Utilities.cairo_rounded_rectangle (
            ctx, stroke_width * 1.5, stroke_width * 1.5,
            width - stroke_width * 3,
            height - stroke_width * 3,
            Utils.scale_to_int (8, monitor_scale)
        );

        ctx.set_line_width (stroke_width);
        ctx.set_source_rgba (
            highlight_color.red / 255.0,
            highlight_color.green / 255.0,
            highlight_color.blue / 255.0,
            0.3
        );
        ctx.stroke ();
        ctx.restore ();
    }
}
