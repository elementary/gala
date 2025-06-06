/*
 * Copyright 2014 Tom Beckmann
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ShadowEffect : Clutter.Effect {
    private const float INITIAL_OPACITY = 0.25f;

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
                    shadow_size = 3;
                    break;
                case "window":
                    shadow_size = 26;
                    break;
                default:
                    shadow_size = 9;
                    break;
            }
        }
    }

    public float monitor_scale { get; construct set; }

    public uint8 shadow_opacity { get; set; default = 255; }
    public int border_radius { get; set; default = 9;}

    private int shadow_size;
    private Cogl.Pipeline? pipeline;
    private string? current_key = null;

    public ShadowEffect (string css_class, float monitor_scale) {
        Object (css_class: css_class, monitor_scale: monitor_scale);
    }

    ~ShadowEffect () {
        if (current_key != null) {
            decrement_shadow_users (current_key);
        }
    }

    public override void set_actor (Clutter.Actor? actor) {
        base.set_actor (actor);

        if (actor != null) {
#if HAS_MUTTER47
            pipeline = new Cogl.Pipeline (actor.context.get_backend ().get_cogl_context ());
#else
            pipeline = new Cogl.Pipeline (Clutter.get_default_backend ().get_cogl_context ());
#endif
        } else {
            pipeline = null;
        }
    }

    private Cogl.Texture? get_shadow (Cogl.Context context, int width, int height, int shadow_size, int border_radius) {
        var old_key = current_key;
        current_key = "%ix%i:%i:%i".printf (width, height, shadow_size, border_radius);
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

        var texture = new Cogl.Texture2D.from_bitmap (get_shadow_bitmap (context, width, height, shadow_size, border_radius));
        shadow_cache.@set (current_key, new Shadow (texture));

        return texture;
    }

    public override void paint (Clutter.PaintNode node, Clutter.PaintContext context, Clutter.EffectPaintFlags flags) {
        var bounding_box = get_bounding_box ();
        var width = (int) (bounding_box.x2 - bounding_box.x1);
        var height = (int) (bounding_box.y2 - bounding_box.y1);

        var shadow = get_shadow (context.get_framebuffer ().get_context (), width, height, Utils.scale_to_int (shadow_size, monitor_scale), Utils.scale_to_int (border_radius, monitor_scale));
        if (shadow != null) {
            pipeline.set_layer_texture (0, shadow);
        }

        var opacity = actor.get_paint_opacity () * shadow_opacity * INITIAL_OPACITY / 255.0f / 255.0f;
        var alpha = Cogl.Color.from_4f (1.0f, 1.0f, 1.0f, opacity);
        alpha.premultiply ();

        pipeline.set_color (alpha);

        context.get_framebuffer ().draw_rectangle (pipeline, bounding_box.x1, bounding_box.y1, bounding_box.x2, bounding_box.y2);

        actor.continue_paint (context);
    }

    private Clutter.ActorBox get_bounding_box () {
        var size = Utils.scale_to_int (shadow_size, monitor_scale);

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

    private Cogl.Bitmap get_shadow_bitmap (Cogl.Context context, int width, int height, int shadow_size, int corner_radius) {
        var data = new uint8[width * height];

        var total_offset = shadow_size + corner_radius;

        var target_row = height - total_offset;
        for (var row = total_offset; row < target_row; row++) {
            var current_row = row * width;
            var current_row_end = current_row + width - 1;
            for (int i = 1; i <= shadow_size; i++) {
                // use efficient and rough Gaussian blur approximation
                var normalized = (double) i / shadow_size;
                var current_color = (uint8) (normalized * normalized * (3.0 - 2.0 * normalized) * 255.0);

                data[current_row + i] = current_color;
                data[current_row_end - i] = current_color;
            }
        }

        var target_col = width - total_offset;
        for (var row = 0; row <= shadow_size; row++) {
            var current_row = row * width;
            var end_row = (height - row) * width - 1;

            // use efficient and rough Gaussian blur approximation
            var normalized = (double) row / shadow_size;
            var current_color = (uint8) (normalized * normalized * (3.0 - 2.0 * normalized) * 255.0);

            for (var col = total_offset; col < target_col; col++) {
                data[current_row + col] = current_color;
                data[end_row - col] = current_color;
            }
        }

        var target_square = shadow_size + corner_radius;
        for (var y = 0; y < target_square; y++) {
            var current_row = width * y;
            var current_row_end = current_row + width - 1;
            var end_row = (height - 1 - y) * width;
            var end_row_end = end_row + width - 1;
            for (var x = 0; x < target_square; x++) {
                var dx = target_square - x;
                var dy = target_square - y;

                var squared_distance = dx * dx + dy * dy;

                if (squared_distance > target_square * target_square) {
                    continue;
                }

                if (squared_distance >= corner_radius * corner_radius) {
                    double sin, cos;
                    Math.sincos (Math.atan2 (dy, dx), out sin, out cos);

                    var real_dx = dx - corner_radius * cos;
                    var real_dy = dy - corner_radius * sin;

                    var real_distance = Math.sqrt (real_dx * real_dx + real_dy * real_dy);

                    // use efficient and rough Gaussian blur approximation
                    var normalized = (double) real_distance / shadow_size;
                    var current_color = (uint8) (1.0 - normalized * normalized * (3.0 - 2.0 * normalized) * 255.0);

                    // when we're very close to the rounded corner, our real_distance can be wrong (idk why).
                    // If we're here, we're not inside the corner yet and that means we must draw something
                    if (current_color == 0) {
                        current_color = 255;
                    }

                    data[current_row + x] = current_color;
                    data[current_row_end - x] = current_color;
                    data[end_row + x] = current_color;
                    data[end_row_end - x] = current_color;
                }
            }
        }

        return new Cogl.Bitmap.for_data (context, width, height, Cogl.PixelFormat.A_8, width, data);
    }
}
