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

        // fill a new texture for this size
        var buffer = new Drawing.BufferSurface (width, height);
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
        Drawing.Utilities.cairo_rounded_rectangle (cr, shadow_size, shadow_size, actor.width, actor.height, border_radius);
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

        var shadow = get_shadow (context.get_framebuffer ().get_context (), width, height, Utils.scale_to_int (shadow_size, monitor_scale), Utils.scale_to_int (border_radius, monitor_scale));
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
}
