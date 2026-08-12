/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

public class Gala.CanvasActor : Clutter.Actor {
    private Gala.Drawing.Canvas canvas;

    construct {
        canvas = new Gala.Drawing.Canvas ();
        content = canvas;
        canvas.draw.connect ((ctx, width, height) => {
            draw (ctx, width, height);
        });
    }

    public override void resource_scale_changed () {
        canvas.set_scale_factor (get_resource_scale ());
    }

    public override void allocate (Clutter.ActorBox box) {
        base.allocate (box);
        canvas.set_size ((int)box.get_width (), (int)box.get_height ());
        canvas.set_scale_factor (get_resource_scale ());
    }

    protected virtual void draw (Cairo.Context canvas, int width, int height) { }
}
