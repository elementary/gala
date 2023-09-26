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
    private static Gee.HashMap<string,Shadow> shadow_cache;
    // Delay the style context creation at render stage as Gtk need to access
    // the current display.
    private static GLib.Once<Gtk.StyleContext> _style_context;

    static construct {
        shadow_cache = new Gee.HashMap<string,Shadow> ();
    }

    private static Gtk.StyleContext create_style_context () {
        var style_path = new Gtk.WidgetPath ();
        style_path.append_type (typeof (Gtk.Window));

        var style_context = new Gtk.StyleContext ();
        style_context.add_provider (Gala.Utils.get_gala_css (), Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);
        style_context.add_class ("decoration");
        style_context.set_path (style_path);
        return style_context;
    }

    public int shadow_size { get; construct; }

    public float scale_factor { get; set; default = 1; }
    public uint8 shadow_opacity { get; set; default = 255; }
    public string? css_class { get; set; default = null; }

    private Cogl.Pipeline pipeline;
    private string? current_key = null;

    public ShadowEffect (int shadow_size) {
        Object (shadow_size: shadow_size);
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

        Shadow? shadow = null;
        if ((shadow = shadow_cache.@get (current_key)) != null) {
            shadow.users++;
            return shadow.texture;
        }

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
        var cr = new Cairo.Context (surface);
        cr.set_source_rgba (0, 0, 0, 0);
        cr.fill ();

        cr.set_operator (Cairo.Operator.OVER);
        cr.save ();
        cr.scale (scale_factor, scale_factor);
        unowned var style_context = _style_context.once (create_style_context);
        style_context.save ();
        if (css_class != null) {
            style_context.add_class (css_class);
        }

        style_context.set_scale ((int) Math.round (scale_factor));
        var size = shadow_size * scale_factor;
        style_context.render_background (cr, shadow_size, shadow_size, (width - size * 2) / scale_factor, (height - size * 2) / scale_factor);
        style_context.restore ();
        cr.restore ();

        cr.paint ();

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

    private void decrement_shadow_users (string key) {
        var shadow = shadow_cache.@get (key);

        if (shadow == null) {
            return;
        }

        if (--shadow.users == 0) {
            shadow_cache.unset (key);
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

        var opacity = actor.get_paint_opacity () * shadow_opacity / 255;
        var alpha = Cogl.Color.from_4ub (255, 255, 255, opacity);
        alpha.premultiply ();

        pipeline.set_color (alpha);

        context.get_framebuffer ().draw_rectangle (pipeline, bounding_box.x1, bounding_box.y1, bounding_box.x2, bounding_box.y2);

        actor.continue_paint (context);
    }

    public virtual Clutter.ActorBox get_bounding_box () {
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
}
