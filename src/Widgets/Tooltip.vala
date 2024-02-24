/*
 * Copyright 2021 José Expósito <jose.exposito89@gmail.com>
 * Copyright 2021-2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * Clutter actor to display text in a tooltip-like component.
 */
public class Gala.Tooltip : CanvasActor {
    /**
     * Actor to display the Tooltip text.
     */
    private Clutter.Text text_actor;

    /**
     * Maximum width of the Tooltip.
     * @see set_max_width
     */
    public float max_width;

    construct {
        max_width = 200;

        Clutter.Color text_color = {
            (uint8) Drawing.Color.TOOLTIP_TEXT_COLOR.red * uint8.MAX,
            (uint8) Drawing.Color.TOOLTIP_TEXT_COLOR.green * uint8.MAX,
            (uint8) Drawing.Color.TOOLTIP_TEXT_COLOR.blue * uint8.MAX,
            (uint8) Drawing.Color.TOOLTIP_TEXT_COLOR.alpha * uint8.MAX,
        };

        text_actor = new Clutter.Text () {
            margin_left = 6,
            margin_top = 6,
            margin_bottom = 6,
            margin_right = 6,
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            color = text_color
        };

        add_child (text_actor);

        layout_manager = new Clutter.BinLayout ();
    }

    public void set_text (string new_text) {
        text_actor.text = new_text;
    }

    public void set_max_width (float new_max_width) {
        max_width = new_max_width;

        queue_relayout ();
    }

    protected override void allocate (Clutter.ActorBox box) {
        if (box.get_width () > max_width) {
            box.set_origin (box.get_x () + ((box.get_width () - max_width) / 2), box.get_y ());
            box.set_size (max_width, box.get_height ());
        }

        base.allocate (box);
    }

    protected override void draw (Cairo.Context ctx, int width, int height) {
        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();
        ctx.set_operator (Cairo.Operator.OVER);

        var background_color = Drawing.Color.TOOLTIP_BACKGROUND;
        ctx.set_source_rgba (
            background_color.red,
            background_color.green,
            background_color.blue,
            background_color.alpha
        );

        Drawing.Utilities.cairo_rounded_rectangle (ctx, 0, 0, width, height, 4);
        ctx.fill ();

        ctx.restore ();
    }
}
