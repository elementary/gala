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

    // Sometimes we use a shadow in only one place and rapidly switch between two shadows
    // In order to not drop them and create them all over again we wait 5 seconds before finally dropping a shadow.
    private static Gee.HashMap<string, uint> shadows_marked_for_dropping;

    static construct {
        shadow_cache = new Gee.HashMap<string, Shadow> ();
        shadows_marked_for_dropping = new Gee.HashMap<string, uint> ();
    }

    private string _css_class;
    public string css_class {
        get {
            return _css_class;
        }

        construct set {
            _css_class = value;
            switch (value) {
                case "workspace-switcher":
                    shadow_size = 6;
                    break;
                case "window":
                    shadow_size = 55;
                    break;
                default:
                    shadow_size = 18;
                    break;
            }
        }
    }

    public float scale_factor { get; set; default = 1; }
    public uint8 shadow_opacity { get; set; default = 255; }
    public int border_radius { get; set; default = 9;}

    private int shadow_size;
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

        // fill a new texture for this size
        var buffer = new ShadowBufferSurface (width, height);
        Drawing.Utilities.cairo_rounded_rectangle (
            buffer.context,
            shadow_size,
            shadow_size,
            width - shadow_size * 2,
            height - shadow_size * 2,
            border_radius
        );

        buffer.context.set_source_rgba (0, 0, 0, 0.7);
        buffer.context.fill ();

        buffer.exponential_blur (shadow_size / 2);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
        var cr = new Cairo.Context (surface);
        cr.set_source_surface (buffer.surface, 0, 0);
        cr.paint ();

        cr.save ();
        cr.set_operator (Cairo.Operator.CLEAR);
        var size = shadow_size * scale_factor;
        Drawing.Utilities.cairo_rounded_rectangle (cr, size, size, actor.width, actor.height, border_radius);
        cr.fill ();
        cr.restore ();

        try {
            var texture = new Cogl.Texture2D.from_data (context, width, height, Cogl.PixelFormat.BGRA_8888_PRE,
                surface.get_stride (), surface.get_data ());
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

        var shadow = get_shadow (context.get_framebuffer ().get_context (), width, height, shadow_size);
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
        var size = shadow_size * scale_factor;
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

        uint timeout_id;
        if (shadows_marked_for_dropping.unset (key, out timeout_id)) {
            Source.remove (timeout_id);
        }
    }

    private static void decrement_shadow_users (string key) {
        var shadow = shadow_cache.@get (key);

        if (shadow == null) {
            return;
        }

        if (--shadow.users == 0) {
            queue_shadow_drop (key);
        }
    }

    private static void queue_shadow_drop (string key) {
        shadows_marked_for_dropping[key] = Timeout.add_seconds (5, () => {
            shadow_cache.unset (key);
            shadows_marked_for_dropping.unset (key);
            return Source.REMOVE;
        });
    }

    private class ShadowBufferSurface : GLib.Object {
        private const int ALPHA_PRECISION = 16;
        private const int PARAM_PRECISION = 7;

        private Cairo.Surface _surface;
        public Cairo.Surface surface {
            get {
                if (_surface == null) {
                    _surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
                }

                return _surface;
            }
            private set { _surface = value; }
        }

        public int width { get; private set; }
        public int height { get; private set; }

        private Cairo.Context _context;
        public Cairo.Context context {
            get {
                if (_context == null) {
                    _context = new Cairo.Context (surface);
                }

                return _context;
            }
        }

        public ShadowBufferSurface (int width, int height) requires (width >= 0 && height >= 0) {
            this.width = width;
            this.height = height;
        }

        construct {
            //  surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
            //  context = new Cairo.Context (surface);
        }

        /**
        * Performs a blur operation on the internal {@link Cairo.Surface}, using an
        * exponential blurring algorithm. This method is usually the fastest
        * and produces good-looking results (though not quite as good as gaussian's).
        *
        * @param radius the blur radius
        */
        public void exponential_blur (int radius) requires (radius > 0) {
            var alpha = (int) ((1 << ALPHA_PRECISION) * (1.0 - Math.exp (-2.3 / (radius + 1.0))));
            var height = this.height;
            var width = this.width;

            var original = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
            var cr = new Cairo.Context (original);

            cr.set_operator (Cairo.Operator.SOURCE);
            cr.set_source_surface (surface, 0, 0);
            cr.paint ();

            uint8 *pixels = original.get_data ();

            try {
                // Process Rows
                var th = new GLib.Thread<void>.try (null, () => {
                    exponential_blur_rows (pixels, width, height, 0, height / 2, 0, width, alpha);
                });

                exponential_blur_rows (pixels, width, height, height / 2, height, 0, width, alpha);
                th.join ();

                // Process Columns
                var th2 = new GLib.Thread<void>.try (null, () => {
                    exponential_blur_columns (pixels, width, height, 0, width / 2, 0, height, alpha);
                });

                exponential_blur_columns (pixels, width, height, width / 2, width, 0, height, alpha);
                th2.join ();
            } catch (Error err) {
                warning (err.message);
            }

            original.mark_dirty ();

            context.set_operator (Cairo.Operator.SOURCE);
            context.set_source_surface (original, 0, 0);
            context.paint ();
            context.set_operator (Cairo.Operator.OVER);
        }

        private void exponential_blur_columns (
            uint8* pixels,
            int width,
            int height,
            int start_col,
            int end_col,
            int start_y,
            int end_y,
            int alpha
        ) {
            for (var column_index = start_col; column_index < end_col; column_index++) {
                // blur columns
                uint8 *column = pixels + column_index * 4;

                var z_alpha = column[0] << PARAM_PRECISION;
                var z_red = column[1] << PARAM_PRECISION;
                var z_green = column[2] << PARAM_PRECISION;
                var z_blue = column[3] << PARAM_PRECISION;

                // Top to Bottom
                for (var index = width * (start_y + 1); index < (end_y - 1) * width; index += width) {
                    exponential_blur_inner (&column[index * 4], ref z_alpha, ref z_red, ref z_green, ref z_blue, alpha);
                }

                // Bottom to Top
                for (var index = (end_y - 2) * width; index >= start_y; index -= width) {
                    exponential_blur_inner (&column[index * 4], ref z_alpha, ref z_red, ref z_green, ref z_blue, alpha);
                }
            }
        }

        private void exponential_blur_rows (
            uint8* pixels,
            int width,
            int height,
            int start_row,
            int end_row,
            int start_x,
            int end_x,
            int alpha
        ) {
            for (var row_index = start_row; row_index < end_row; row_index++) {
                // Get a pointer to our current row
                uint8* row = pixels + row_index * width * 4;

                var z_alpha = row[start_x + 0] << PARAM_PRECISION;
                var z_red = row[start_x + 1] << PARAM_PRECISION;
                var z_green = row[start_x + 2] << PARAM_PRECISION;
                var z_blue = row[start_x + 3] << PARAM_PRECISION;

                // Left to Right
                for (var index = start_x + 1; index < end_x; index++)
                    exponential_blur_inner (&row[index * 4], ref z_alpha, ref z_red, ref z_green, ref z_blue, alpha);

                // Right to Left
                for (var index = end_x - 2; index >= start_x; index--)
                    exponential_blur_inner (&row[index * 4], ref z_alpha, ref z_red, ref z_green, ref z_blue, alpha);
            }
        }

        private static inline void exponential_blur_inner (
            uint8* pixel,
            ref int z_alpha,
            ref int z_red,
            ref int z_green,
            ref int z_blue,
            int alpha
        ) {
            z_alpha += (alpha * ((pixel[0] << PARAM_PRECISION) - z_alpha)) >> ALPHA_PRECISION;
            z_red += (alpha * ((pixel[1] << PARAM_PRECISION) - z_red)) >> ALPHA_PRECISION;
            z_green += (alpha * ((pixel[2] << PARAM_PRECISION) - z_green)) >> ALPHA_PRECISION;
            z_blue += (alpha * ((pixel[3] << PARAM_PRECISION) - z_blue)) >> ALPHA_PRECISION;

            pixel[0] = (uint8) (z_alpha >> PARAM_PRECISION);
            pixel[1] = (uint8) (z_red >> PARAM_PRECISION);
            pixel[2] = (uint8) (z_green >> PARAM_PRECISION);
            pixel[3] = (uint8) (z_blue >> PARAM_PRECISION);
        }
    }
}
