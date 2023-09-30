/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.SeparatorMenuItem : Clutter.Actor {
    private Clutter.Canvas canvas;

    private float _scale_factor = 1.0f;
    public float scale_factor {
        get {
            return _scale_factor;
        }
        set {
            _scale_factor = value;
            canvas.scale_factor = _scale_factor;

            canvas.invalidate ();
        }
    }

    public SeparatorMenuItem (float scale_factor) {
        canvas = new Clutter.Canvas ();
        canvas.draw.connect (draw_background);

        set_content (canvas);

        set_size (1, 2);
        canvas.set_size (1, 2);

        margin_top = 3;
        margin_bottom = 3;

        this.scale_factor = scale_factor;
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
        ctx.rectangle (0, 0, width, 1);
        ctx.fill ();

        ctx.set_source_rgba (255, 255, 255, bottom_alpha);
        ctx.rectangle (0, 1, width, 1);
        ctx.fill ();

        ctx.restore ();

        return true;
    }
}
