/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

#if HAS_MUTTER46
public class Gala.Drawing.Canvas : GLib.Object, Clutter.Content {
    private int width = -1;
    private int height = -1;
    private float scale_factor = 1.0f;

    private Cogl.Texture? texture = null;
    private Cairo.ImageSurface? surface = null;

    private bool dirty = false;

    private void emit_draw () requires (width > 0 && height > 0) {
        dirty = true;
        int real_width = (int) Math.ceilf (width * scale_factor);
        int real_height = (int) Math.ceilf (height * scale_factor);

        surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, real_width, real_height);
        surface.set_device_scale (scale_factor, scale_factor);
        var cr = new Cairo.Context (surface);

        draw ((owned) cr, width, height, scale_factor);
    }

    public bool get_preferred_size (out float out_width, out float out_height) {
        if (width < 0 || width < 0) {
            out_width = 0;
            out_height = 0;
            return false;
        }

        out_width = Math.ceilf (width * scale_factor);
        out_height = Math.ceilf (height * scale_factor);

        return true;
    }

    public void invalidate () {
        if (width < 0 || height < 0) {
            return;
        }

        emit_draw ();
    }

    public void invalidate_size () { }

    public void paint_content (Clutter.Actor actor, Clutter.PaintNode root, Clutter.PaintContext paint_context) {
        if (surface == null) {
            return;
        }

        if (dirty) {
            texture = null;
        }

        if (texture == null) {
            try {
                texture = new Cogl.Texture2D.from_data (
                    context.get_framebuffer ().get_context (),
                    width,
                    height,
                    Cogl.PixelFormat.BGRA_8888_PRE,
                    surface.get_stride (),
                    surface.get_data ()
                );
            } catch (Error e) {
                critical ("Failed to create texture: %s", e.message);
            }
        }

        if (texture == null) {
            return;
        }

        //  var node = actor.create_texture_paint_node (texture);
        //  root.add_child (node);

        dirty = false;
    }

    public void set_size (int new_width, int new_height) requires (new_width >= -1 && new_height >= -1) {
        if (new_width == width && new_height == height) {
            return;
        }

        width = new_width;
        height = new_height;

        invalidate ();
    }

    public void set_scale_factor (float new_scale_factor) requires (new_scale_factor > 0.0f) {
        if (new_scale_factor != scale_factor) {
            scale_factor = new_scale_factor;

            invalidate ();
        }
    }


    public virtual signal void draw (Cairo.Context cr, int width, int height, float scale_factor);
}
#else
public class Gala.Drawing.Canvas : GLib.Object, Clutter.Content {
    public Clutter.Canvas canvas;

    construct {
        canvas = new Clutter.Canvas ();
        canvas.draw.connect (on_draw);
    }

    public bool get_preferred_size (out float out_width, out float out_height) {
        return canvas.get_preferred_size (out out_width, out out_height);
    }

    public void invalidate () {
        canvas.invalidate ();
    }

    public void invalidate_size () {
        canvas.invalidate_size ();
    }

    public void paint_content (Clutter.Actor actor, Clutter.PaintNode root, Clutter.PaintContext paint_context) {
        canvas.paint_content (actor, root, paint_context);
    }

    public void set_size (int new_width, int new_height) requires (new_width >= -1 && new_height >= -1) {
        canvas.set_size (new_width, new_height);
    }

    public void set_scale_factor (float new_scale_factor) requires (new_scale_factor > 0.0f) {
        canvas.set_scale_factor (new_scale_factor);
    }

    private bool on_draw (Cairo.Context cr, int width, int height) {
        draw (cr, width, height, canvas.get_scale_factor ());
        return true;
    }

    public virtual signal void draw (Cairo.Context cr, int width, int height, float scale_factor);
}
#endif
