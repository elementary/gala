/*
 * Copyright 2014 Tom Beckmann
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ShadowEffect : Clutter.Effect {
    private class Shadow {
        public int users;
        public Cogl.Texture texture;

        public Shadow (Cogl.Texture _texture) {
            texture = _texture;
            users = 1;
        }
    }

    // the sizes of the textures often repeat, especially for the background actor
    // so we keep a cache to avoid creating the same texture all over again.
    private static Gee.HashMap<string, Shadow> shadow_cache;

    static construct {
        shadow_cache = new Gee.HashMap<string, Shadow> ();
    }

    public string css_class {
        construct set {
            switch (value) {
                case "workspace-switcher":
                    radius = 6;
                    break;
                case "window":
                    radius = 10;
                    break;
                default:
                    radius = 8;
                    break;
            }
        }
    }

    public float scale_factor { get; set; default = 1; }
    public uint8 shadow_opacity { get; set; default = 255; }
    public int border_radius { get; set; default = 9;}

    private int radius;
    private Cogl.Pipeline pipeline;
    private string? current_key = null;

    public ShadowEffect (string css_class = "") {
        Object (css_class: css_class);
    }

    construct {
        pipeline = new Cogl.Pipeline (Clutter.get_default_backend ().get_cogl_context ());
    }

    ~ShadowEffect () {
        if (current_key != null) {
            decrement_shadow_users (current_key);
        }
    }

    private Cogl.Texture? get_shadow (Cogl.Context context, int width, int height, int shadow_size) {
        var old_key = current_key;
        current_key = "%ix%i:%i".printf (width, height, shadow_size);
        if (old_key == current_key) {
            return null;
        }

        if (old_key != null) {
            decrement_shadow_users (old_key);
        }

        var shadow = shadow_cache.@get (current_key);
        if (shadow != null) {
            increment_shadow_users (current_key);
            return shadow.texture;
        }

        var buffer = new uint8[width * height];
        var buffer_ptr = &buffer[0];

        for (int row_i = shadow_size; row_i < height - shadow_size; row_i++) {
            Memory.set (buffer_ptr + width * row_i + shadow_size, 255, width - shadow_size * 2);
        }

        flip_buffer (buffer_ptr, width, height);

        var d = get_box_filter_size ();
        blur_rows (buffer_ptr, height, width, d);

        flip_buffer (buffer_ptr, height, width);

        //  blur_rows (buffer_ptr, width, height, d);

        //  // fill a new texture for this size
        //  var buffer = new Drawing.BufferSurface (width, height);
        //  Drawing.Utilities.cairo_rounded_rectangle (
        //      buffer.context,
        //      shadow_size,
        //      shadow_size,
        //      width - shadow_size * 2,
        //      height - shadow_size * 2,
        //      border_radius
        //  );

        //  buffer.context.set_source_rgba (0, 0, 0, 0.7);
        //  buffer.context.fill ();

        //  buffer.exponential_blur (shadow_size / 2);

        //  var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
        //  var cr = new Cairo.Context (surface);
        //  cr.set_source_surface (buffer.surface, 0, 0);
        //  cr.paint ();

        //  cr.save ();
        //  cr.set_operator (Cairo.Operator.CLEAR);
        //  var size = shadow_size * scale_factor;
        //  Drawing.Utilities.cairo_rounded_rectangle (cr, size, size, actor.width, actor.height, border_radius);
        //  cr.fill ();
        //  cr.restore ();

        try {
            var texture = new Cogl.Texture2D.from_data (context, width, height, Cogl.PixelFormat.A_8, width, buffer);
            shadow_cache.@set (current_key, new Shadow (texture));

            return texture;
        } catch (Error e) {
            debug (e.message);
            return null;
        }
    }

    public override void paint (Clutter.PaintNode node, Clutter.PaintContext context, Clutter.EffectPaintFlags flags) {
        var bounding_box = get_bounding_box ();
        var width = (int) (bounding_box.x2 - bounding_box.x1);
        var height = (int) (bounding_box.y2 - bounding_box.y1);

        var shadow = get_shadow (context.get_framebuffer ().get_context (), width, height, get_shadow_spread ());
        if (shadow != null) {
            pipeline.set_layer_texture (0, shadow);
        }

        var opacity = actor.get_paint_opacity () * shadow_opacity / 255.0f;
        var alpha = Cogl.Color.from_4f (1.0f, 1.0f, 1.0f, opacity / 255.0f);
        alpha.premultiply ();

        pipeline.set_color (alpha);

        context.get_framebuffer ().draw_rectangle (pipeline, bounding_box.x1, bounding_box.y1, bounding_box.x2, bounding_box.y2);

        actor.continue_paint (context);
    }

    private Clutter.ActorBox get_bounding_box () {
        var size = get_shadow_spread () * scale_factor;
        var bounding_box = Clutter.ActorBox ();

        bounding_box.set_origin (-size, -size);
        bounding_box.set_size (actor.width + size * 2, actor.height + size * 2);

        return bounding_box;
    }

    public override bool modify_paint_volume (Clutter.PaintVolume volume) {
        var bounding_box = get_bounding_box ();

        volume.set_width (bounding_box.get_width ());
        volume.set_height (bounding_box.get_height ());

        float origin_x, origin_y;
        bounding_box.get_origin (out origin_x, out origin_y);
        var origin = volume.get_origin ();
        origin.x += origin_x;
        origin.y += origin_y;
        volume.set_origin (origin);

        return true;
    }

    private static void increment_shadow_users (string key) {
        var shadow = shadow_cache.@get (key);

        if (shadow == null) {
            return;
        }

        shadow.users++;
    }

    private static void decrement_shadow_users (string key) {
        var shadow = shadow_cache.@get (key);

        if (shadow == null) {
            return;
        }

        if (--shadow.users == 0) {
            shadow_cache.unset (key);
        }
    }

    private void flip_buffer (uint8* buffer, int width, int height) {
        /* Working in blocks increases cache efficiency, compared to reading
         * or writing an entire column at once */
        var BLOCK_SIZE = 16;

        var new_buffer = new uint8[width * height];
        var new_buffer_ptr = &new_buffer[0];

        for (var i0 = 0; i0 < width; i0 += BLOCK_SIZE) {
            int max_i = int.min (i0 + BLOCK_SIZE, width);

            for (var j0 = 0; j0 < height; j0 += BLOCK_SIZE) {
                int max_j = int.min (j0 + BLOCK_SIZE, height);

                for (var i = i0; i < max_i; i++) {
                    for (var j = j0; j < max_j; j++) {
                        new_buffer[i * height + j] = buffer[j * width + i];
                    }
                }
            }
        }

        Memory.copy (buffer, new_buffer_ptr, width * height);
    }

    private int get_box_filter_size () {
        return (int) (0.5 + radius * (0.75 * Math.sqrt (2 * Math.PI)));
    }

    /* The "spread" of the filter is the number of pixels from an original
     * pixel that it's blurred image extends. (A no-op blur that doesn't
     * blur would have a spread of 0.) See comment in blur_rows() for why the
     * odd and even cases are different
     */
    private int get_shadow_spread () {
        if (radius == 0) {
            return 0;
        }

        var d = get_box_filter_size ();

        if (d % 2 == 1) {
            return 3 * (d / 2);
        } else {
            return 3 * (d / 2) - 1;
        }
    }

    private void blur_rows (
        uint8* buffer,
        int width,
        int height,
        int d
    ) {
        for (var row_i = 0; row_i < height; row_i++) {
            uint8* row = buffer + width * row_i;

            /* We want to produce a symmetric blur that spreads a pixel
             * equally far to the left and right. If d is odd that happens
             * naturally, but for d even, we approximate by using a blur
             * on either side and then a centered blur of size d + 1.
             * (technique also from the SVG specification)
             */
            if (d % 2 == 1) {
                blur_xspan (row, width, d, 0);
                //  blur_xspan (row, width, d, 0);
                //  blur_xspan (row, width, d, 0);
            } else {
                blur_xspan (row, width, d, 1);
                //  blur_xspan (row, width, d, -1);
                //  blur_xspan (row, width, d + 1, 0);
            }
        }
    }

    /* This applies a single box blur pass to a horizontal range of pixels;
     * since the box blur has the same weight for all pixels, we can
     * implement an efficient sliding window algorithm where we add
     * in pixels coming into the window from the right and remove
     * them when they leave the windw to the left.
     *
     * d is the filter width; for even d shift indicates how the blurred
     * result is aligned with the original - does ' x ' go to ' yy' (shift=1)
     * or 'yy ' (shift=-1)
     */
    private void blur_xspan (
        uint8* row,
        int width,
        int d,
        int shift
    ) {       
        var tmp_buffer = new uint8[width];
        var tmp_buffer_ptr = &tmp_buffer[0];
        
        var spread = get_shadow_spread ();

        var sum = 0;
        var left_bound = spread +  + border_radius + d;
        for (var i = 0; i <= left_bound; i++) {
            sum += row[i];

            if (i >= d) {
                sum -= row[i - d];
            }

            if (i >= spread) {
                //  tmp_buffer[i - spread] = (uint8) (sum / d + 0.5);
                tmp_buffer[i - spread] = 255;
            }
        }

        Memory.copy (row, tmp_buffer_ptr, left_bound + 1);

        sum = 0;
        var right_bound = width - spread - border_radius - d;
        for (var i = width - 1; i >= right_bound; i--) {
            sum += row[i];

            if (i <= width - d) {
                sum -= row[i + d];
            }

            if (i <= width - spread) {
                //  tmp_buffer[i + spread] = (uint8) (sum / d + 0.5);
                tmp_buffer[i - spread] = 255;
            }
        }

        Memory.copy (row + right_bound, tmp_buffer_ptr, width - 1 - right_bound);
    }
}
