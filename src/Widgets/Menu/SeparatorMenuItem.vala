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

        set_size (1, 1);
        canvas.set_size (1, 1);

        this.scale_factor = scale_factor;
    }

    private bool draw_background (Cairo.Context ctx, int width, int height) {
        ctx.save ();
        ctx.set_operator (Cairo.Operator.OVER);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();

        var separator = new Gtk.Separator (HORIZONTAL) {
            visible = true
        };
        Gtk.Allocation alloc = {
            0,
            0,
            width,
            height
        };
        separator.size_allocate (alloc);
        separator.draw (ctx);
        ctx.restore ();

        return true;
    }
}
