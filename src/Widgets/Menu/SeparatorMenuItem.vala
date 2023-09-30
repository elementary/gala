/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.SeparatorMenuItem : Clutter.Actor {
    private Clutter.Canvas canvas;

    public SeparatorMenuItem () {
        canvas = new Clutter.Canvas ();
        canvas.draw.connect (draw_background);

        set_content (canvas);

        notify["allocation"].connect (() => canvas.set_size ((int) width, (int) height));
    }

    public void scale (float scale_factor) {
        height = InternalUtils.scale_to_int (2, scale_factor);
        margin_top = margin_bottom = InternalUtils.scale_to_int (3, scale_factor);
    }

    private bool draw_background (Cairo.Context ctx, int width, int height) {
        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();

        ctx.set_operator (Cairo.Operator.SOURCE);

        double top_alpha, bottom_alpha;

        if (Granite.Settings.get_default ().prefers_color_scheme == DARK) {
            top_alpha = 0.35;
            bottom_alpha = 0.05;
        } else {
            top_alpha = 0.15;
            bottom_alpha = 0.8;
        }

        ctx.set_source_rgba (0, 0, 0, top_alpha);
        ctx.rectangle (0, 0, width, height / 2);
        ctx.fill ();

        ctx.set_source_rgba (255, 255, 255, bottom_alpha);
        ctx.rectangle (0, height / 2, width, height / 2);
        ctx.fill ();

        ctx.restore ();

        return true;
    }
}
