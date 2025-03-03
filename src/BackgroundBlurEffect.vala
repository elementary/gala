/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.BackgroundBlurEffect : Clutter.Effect {
    private const float MIN_DOWNSCALE_SIZE = 256.0f;
    private const float MAX_RADIUS = 12.0f;
    private const int FORCE_REFRESH_FRAMES = 2;

    public new Clutter.Actor actor { get; construct; }
    public float radius { get; construct; }
    public float brightness { get; construct; }

    private float downscale_factor;

    private bool actor_painted = false;
    private bool blur_applied = false;

    private int texture_width;
    private int texture_height;

    private Cogl.Framebuffer actor_framebuffer;
    private Cogl.Pipeline actor_pipeline;
    private Cogl.Texture actor_texture;

    private Cogl.Framebuffer background_framebuffer;
    private Cogl.Pipeline background_pipeline;
    private Cogl.Texture background_texture;

    private Cogl.Framebuffer brightness_framebuffer;
    private Cogl.Pipeline brightness_pipeline;
    private Cogl.Texture brightness_texture;
    private int brightness_uniform;

    private int counter = 0;

    public BackgroundBlurEffect (Clutter.Actor actor, float radius, float brightness) {
        Object (actor: actor, radius: radius, brightness: brightness);
    }

    construct {
#if HAS_MUTTER47
        unowned var ctx = actor.context.get_backend ().get_cogl_context ();
#else
        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();
#endif

        actor_pipeline = new Cogl.Pipeline (ctx);
        actor_pipeline.set_layer_null_texture (0);
        actor_pipeline.set_layer_filters (0, Cogl.PipelineFilter.LINEAR, Cogl.PipelineFilter.LINEAR);
        actor_pipeline.set_layer_wrap_mode (0, Cogl.PipelineWrapMode.CLAMP_TO_EDGE);

        background_pipeline = new Cogl.Pipeline (ctx);
        background_pipeline.set_layer_null_texture (0);
        background_pipeline.set_layer_filters (0, Cogl.PipelineFilter.LINEAR, Cogl.PipelineFilter.LINEAR);
        background_pipeline.set_layer_wrap_mode (0, Cogl.PipelineWrapMode.CLAMP_TO_EDGE);

        brightness_pipeline = new Cogl.Pipeline (ctx);
        brightness_pipeline.set_layer_null_texture (0);
        brightness_pipeline.set_layer_filters (0, Cogl.PipelineFilter.LINEAR, Cogl.PipelineFilter.LINEAR);
        brightness_pipeline.set_layer_wrap_mode (0, Cogl.PipelineWrapMode.CLAMP_TO_EDGE);
        brightness_pipeline.add_snippet (
            new Cogl.Snippet (
                Cogl.SnippetHook.FRAGMENT, "uniform float brightness;", "cogl_color_out.rgb *= brightness;"
            )
        );

        brightness_uniform = brightness_pipeline.get_uniform_location ("brightness");
    }

    private void update_actor_box (Clutter.PaintContext paint_context, ref Clutter.ActorBox source_actor_box) {
        float box_scale_factor = 1.0f;
        float origin_x, origin_y;
        float width, height;

        var stage_view = paint_context.get_stage_view ();
    
        actor.get_transformed_position (out origin_x, out origin_y);
        actor.get_transformed_size (out width, out height);
    
        if (stage_view != null) {
            Mtk.Rectangle stage_view_layout = {};
    
            box_scale_factor = stage_view.get_scale ();
            stage_view.get_layout (ref stage_view_layout);
    
            origin_x -= stage_view_layout.x;
            origin_y -= stage_view_layout.y;
        } else {
            /* If we're drawing off stage, just assume scale = 1, this won't work
             * with stage-view scaling though.
             */
        }
    
        source_actor_box.set_origin (origin_x, origin_y);
        source_actor_box.set_size (width, height);
    
        source_actor_box.scale (box_scale_factor);
      
        Clutter.ActorBox.clamp_to_pixel (ref source_actor_box);
    }

    private float calculate_downscale_factor (float width, float height, float radius) {
        float downscale_factor = 1.0f;
        float scaled_width = width;
        float scaled_height = height;
        float scaled_radius = radius;

        /* This is the algorithm used by Firefox; keep downscaling until either the
         * blur radius is lower than the threshold, or the downscaled texture is too
         * small.
         */
        while (
            scaled_radius > MAX_RADIUS &&
            scaled_width > MIN_DOWNSCALE_SIZE &&
            scaled_height > MIN_DOWNSCALE_SIZE
        ) {
            downscale_factor *= 2.0f;

            scaled_width = width / downscale_factor;
            scaled_height = height / downscale_factor;
            scaled_radius = radius / downscale_factor;
        }

        return downscale_factor;
    }

    private void update_brightness () {
        if (brightness_uniform > -1) {
            brightness_pipeline.set_uniform_1f (brightness_uniform, brightness);
        }
    }

    private void setup_projection_matrix (Cogl.Framebuffer framebuffer, float width, float height) {
        Graphene.Matrix projection = {};
        projection.init_translate ({ -width / 2.0f, -height / 2.0f, 0.0f });
        projection.scale (2.0f / width, -2.0f / height, 1.0f);

        framebuffer.set_projection_matrix (projection);
    }

    private bool update_actor_fbo (int width, int height, float downscale_factor) {
        if (
            texture_width == width &&
            texture_height == height &&
            this.downscale_factor == downscale_factor &&
            actor_framebuffer != null
        ) {
            return true;
        }

        actor_painted = false;

#if HAS_MUTTER47
        unowned var ctx = actor.context.get_backend ().get_cogl_context ();
#else
        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();
#endif

        var new_width = (int) Math.floorf (width / downscale_factor);
        var new_height = (int) Math.floorf (height / downscale_factor);

        actor_texture = new Cogl.Texture2D.with_size (ctx, new_width, new_height);
        actor_pipeline.set_layer_texture (0, actor_texture);
        actor_framebuffer = new Cogl.Offscreen.with_texture (actor_texture);

        setup_projection_matrix (actor_framebuffer, new_width, new_height);

        return true;
    }

    private bool update_brightness_fbo (int width, int height, float downscale_factor) {
        if (
            texture_width == width &&
            texture_height == height &&
            this.downscale_factor == downscale_factor &&
            brightness_framebuffer != null
        ) {
            return true;
        }

#if HAS_MUTTER47
        unowned var ctx = actor.context.get_backend ().get_cogl_context ();
#else
        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();
#endif

        var new_width = (int) Math.floorf (width / downscale_factor);
        var new_height = (int) Math.floorf (height / downscale_factor);

        brightness_texture = new Cogl.Texture2D.with_size (ctx, new_width, new_height);
        brightness_pipeline.set_layer_texture (0, brightness_texture);
        brightness_framebuffer = new Cogl.Offscreen.with_texture (brightness_texture);

        setup_projection_matrix (brightness_framebuffer, new_width, new_height);

        return true;
    }

    private bool update_background_fbo (int width, int height) {
        if (
            texture_width == width &&
            texture_height == height &&
            background_framebuffer != null
        ) {
            return true;
        }

#if HAS_MUTTER47
        unowned var ctx = actor.context.get_backend ().get_cogl_context ();
#else
        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();
#endif

        background_texture = new Cogl.Texture2D.with_size (ctx, width, height);
        background_pipeline.set_layer_texture (0, background_texture);
        background_framebuffer = new Cogl.Offscreen.with_texture (background_texture);

        setup_projection_matrix (background_framebuffer, width, height);

        return true;
    }

    private bool update_framebuffers (Clutter.PaintContext paint_context, Clutter.ActorBox actor_box) {
        var width = (int) actor_box.get_width ();
        var height = (int) actor_box.get_height ();

        var downscale_factor = calculate_downscale_factor (width, height, radius);

        var updated = update_actor_fbo (width, height, downscale_factor) && update_brightness_fbo (width, height, downscale_factor) && update_background_fbo (width, height);

        texture_width = width;
        texture_height = height;
        this.downscale_factor = downscale_factor;

        return updated;
    }

    private Clutter.PaintNode create_blur_nodes (Clutter.PaintNode node) {
        float width, height;
        actor.get_size (out width, out height);

        update_brightness ();

        var brightness_node = new Clutter.LayerNode.to_framebuffer (brightness_framebuffer, brightness_pipeline);
        node.add_child (brightness_node);
        brightness_node.add_rectangle ({ 0.0f, 0.0f, width, height });

        var blur_node = new Clutter.BlurNode (
            (uint) (texture_width / downscale_factor),
            (uint) (texture_height / downscale_factor),
            radius / downscale_factor
        );
        brightness_node.add_child (blur_node);
        blur_node.add_rectangle ({
            0.0f,
            0.0f,
            brightness_texture.get_width (),
            brightness_texture.get_height ()
        });

        blur_applied = true;

        return blur_node;
    }

    private void add_actor_node (Clutter.PaintNode node) {
        var actor_node = new Clutter.ActorNode (actor, -1);
        node.add_child (actor_node);
    }

    private void paint_background (Clutter.PaintNode node, Clutter.PaintContext paint_context, Clutter.ActorBox source_actor_box) {
        float transformed_x, transformed_y, transformed_width, transformed_height;
      
        source_actor_box.get_origin (out transformed_x, out transformed_y);
        source_actor_box.get_size (out transformed_width, out transformed_height);

        /* Background layer node */
        var background_node = new Clutter.LayerNode.to_framebuffer (background_framebuffer, background_pipeline);
        node.add_child (background_node);
        background_node.add_rectangle ({ 0.0f, 0.0f, texture_width / downscale_factor, texture_height / downscale_factor });

        /* Blit node */
        var blit_node = new Clutter.BlitNode (paint_context.get_stage_view ().get_framebuffer ());
        background_node.add_child (blit_node);
        blit_node.add_blit_rectangle (
            (int) transformed_x,
            (int) transformed_y,
            0, 0,
            (int) transformed_width,
            (int) transformed_height
        );
    }

    public override void paint_node (Clutter.PaintNode node, Clutter.PaintContext paint_context, Clutter.EffectPaintFlags flags) {
        warning ("OwO, repainting");

        if (radius <= 0) {
            // fallback to drawing actor
            add_actor_node (node);
            return;
        }

        Clutter.ActorBox source_actor_box = {};
        update_actor_box (paint_context, ref source_actor_box);

        /* Failing to create or update the offscreen framebuffers prevents
         * the entire effect to be applied.
         */
        if (!update_framebuffers (paint_context, source_actor_box)) {
            add_actor_node (node);
            return;
        }

        var blur_node = create_blur_nodes (node);
        paint_background (blur_node, paint_context, source_actor_box);
        add_actor_node (node);
    }

    public override void paint (Clutter.PaintNode node, Clutter.PaintContext paint_context, Clutter.EffectPaintFlags flags) {
        if (counter == 0) {
            counter = FORCE_REFRESH_FRAMES;
            queue_repaint ();
        } else {
            counter--;
        }

        base.paint (node, paint_context, flags);
    }
}
