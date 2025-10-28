/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

public class Gala.RoundedCornersEffect : Clutter.Effect {
    public float clip_radius { get; construct; }
    public float monitor_scale { get; construct set; }

    private Cogl.Framebuffer round_framebuffer;
    private Cogl.Pipeline round_pipeline;
    private Cogl.Texture round_texture;
    private int round_clip_radius_location;
    private int round_actor_size_location;

    public RoundedCornersEffect (float clip_radius, float monitor_scale) {
        Object (clip_radius: clip_radius, monitor_scale: monitor_scale);
    }

    construct {
#if HAS_MUTTER47
        unowned var ctx = actor.context.get_backend ().get_cogl_context ();
#else
        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();
#endif

        round_pipeline = new Cogl.Pipeline (ctx);
        round_pipeline.set_layer_null_texture (0);
        round_pipeline.set_layer_filters (0, Cogl.PipelineFilter.LINEAR, Cogl.PipelineFilter.LINEAR);
        round_pipeline.set_layer_wrap_mode (0, Cogl.PipelineWrapMode.CLAMP_TO_EDGE);
        round_pipeline.add_snippet (
            new Cogl.Snippet (
                Cogl.SnippetHook.FRAGMENT,
                """
                uniform sampler2D tex;
                uniform vec2 actor_size;
                uniform float clip_radius;

                float rounded_rect_coverage (vec2 p) {
                    float center_left = clip_radius;
                    float center_right = actor_size.x - clip_radius;

                    float center_x;
                    if (p.x < center_left) {
                        center_x = center_left;
                    } else if (p.x > center_right) {
                        center_x = center_right;
                    } else {
                        return 1.0;
                    }

                    float center_top = clip_radius;
                    float center_bottom = actor_size.y - clip_radius;

                    float center_y;
                    if (p.y < center_top) {
                        center_y = center_top;
                    } else if (p.y > center_bottom) {
                        center_y = center_bottom;
                    } else {
                        return 1.0;
                    }

                    vec2 delta = p - vec2 (center_x, center_y);
                    float dist_squared = dot (delta, delta);

                    // Fully outside the circle
                    float outer_radius = clip_radius + 0.5;
                    if (dist_squared >= (outer_radius * outer_radius)) {
                        return 0.0;
                    }

                    // Fully inside the circle
                    float inner_radius = clip_radius - 0.5;
                    if (dist_squared <= (inner_radius * inner_radius)) {
                        return 1.0;
                    }
                    // Only pixels on the edge of the curve need expensive antialiasing
                    return smoothstep (outer_radius, inner_radius, sqrt (dist_squared));
                }
                """,

                """
                vec4 sample = texture2D (tex, cogl_tex_coord0_in.xy);
                vec2 texture_coord = cogl_tex_coord0_in.xy * actor_size;
                float res = rounded_rect_coverage (texture_coord);
                cogl_color_out = sample * cogl_color_in * res;
                """
            )
        );

        round_clip_radius_location = round_pipeline.get_uniform_location ("clip_radius");
        round_actor_size_location = round_pipeline.get_uniform_location ("actor_size");

        update_clip_radius ();
        update_actor_size ();

        notify["monitor-scale"].connect (update_clip_radius);
    }

    public override void set_actor (Clutter.Actor? new_actor) {
        if (actor != null) {
            actor.notify["width"].disconnect (update_actor_size);
            actor.notify["height"].disconnect (update_actor_size);
        }

        base.set_actor (new_actor);

        if (actor != null) {
            actor.notify["width"].connect (update_actor_size);
            actor.notify["height"].connect (update_actor_size);
            update_actor_size ();
        }
    }

    private void update_clip_radius () {
        float[] _clip_radius = { clip_radius * monitor_scale };
        round_pipeline.set_uniform_float (round_clip_radius_location, 1, 1, _clip_radius);
    }

    private void update_actor_size () {
        if (actor == null) {
            return;
        }

        float[] actor_size = {
            actor.width,
            actor.height
        };

        round_pipeline.set_uniform_float (round_actor_size_location, 2, 1, actor_size);
    }

    private void setup_projection_matrix (Cogl.Framebuffer framebuffer, float width, float height) {
        Graphene.Matrix projection = {};
        projection.init_translate ({ -width / 2.0f, -height / 2.0f, 0.0f });
        projection.scale (2.0f / width, -2.0f / height, 1.0f);

        framebuffer.set_projection_matrix (projection);
    }

    private bool update_rounded_fbo (int width, int height) {
#if HAS_MUTTER47
        unowned var ctx = actor.context.get_backend ().get_cogl_context ();
#else
        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();
#endif

#if HAS_MUTTER46
        round_texture = new Cogl.Texture2D.with_size (ctx, width, height);
#else
        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
        try {
            round_texture = new Cogl.Texture2D.from_data (ctx, width, height, Cogl.PixelFormat.BGRA_8888_PRE, surface.get_stride (), surface.get_data ());
        } catch (Error e) {
            critical ("BackgroundBlurEffect: Couldn't create round_texture: %s", e.message);
            return false;
        }
#endif

        round_pipeline.set_layer_texture (0, round_texture);
        round_framebuffer = new Cogl.Offscreen.with_texture (round_texture);

        setup_projection_matrix (round_framebuffer, width, height);

        return true;
    }

    private bool update_framebuffers (Clutter.PaintContext paint_context) {
        if (actor == null) {
            return false;
        }

        var width = (int) actor.width;
        var height = (int) actor.height;

        if (width <= 0 || height <= 0) {
            warning ("RoundedCornersEffect: Couldn't update framebuffers, incorrect size");
            return false;
        }

        return update_rounded_fbo (width, height);
    }

    private Clutter.PaintNode create_round_nodes (Clutter.PaintNode node) {
        var round_node = new Clutter.LayerNode.to_framebuffer (round_framebuffer, round_pipeline);
        round_node.add_rectangle ({ 0.0f, 0.0f, actor.width, actor.height });

        node.add_child (round_node);

        return round_node;
    }

    private void add_actor_node (Clutter.PaintNode node) {
        var actor_node = new Clutter.ActorNode (actor, -1);
        node.add_child (actor_node);
    }

    public override void paint_node (Clutter.PaintNode node, Clutter.PaintContext paint_context, Clutter.EffectPaintFlags flags) {
        /* Failing to create or update the offscreen framebuffers prevents
         * the entire effect to be applied.
         */
        if (!update_framebuffers (paint_context)) {
            add_actor_node (node);
            return;
        }

        add_actor_node (create_round_nodes (node));
    }
}
