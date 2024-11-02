/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public enum Gala.BlurMode {
    BLUR_ACTOR,
    BLUR_BACKGROUND
}

public class Gala.BlurEffect : Clutter.Effect {
    private const float MIN_DOWNSCALE_SIZE = 256.0f;
    private const float MAX_RADIUS = 12.0f;
    
    public new Clutter.Actor actor { get; construct; }
    public BlurMode mode { get; construct; }
    public float radius { get; construct; }

    private bool actor_painted = false;
    private bool blur_applied = false;

    private int texture_width;
    private int texture_height;
    private float downscale_factor;

    private Cogl.Framebuffer actor_framebuffer;
    private Cogl.Pipeline actor_pipeline;
    private Cogl.Texture actor_texture;

    private Cogl.Framebuffer framebuffer;
    private Cogl.Pipeline pipeline;
    private Cogl.Texture texture;

    private Cogl.Framebuffer background_framebuffer;
    private Cogl.Pipeline background_pipeline;
    private Cogl.Texture background_texture;

    public BlurEffect (Clutter.Actor actor, BlurMode mode, float radius) {
        Object (actor: actor, mode: mode, radius: radius);
    }

    construct {
        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();

        actor_pipeline = new Cogl.Pipeline (ctx);
        actor_pipeline.set_layer_null_texture (0);
        actor_pipeline.set_layer_filters (0, Cogl.PipelineFilter.LINEAR, Cogl.PipelineFilter.LINEAR);
        actor_pipeline.set_layer_wrap_mode (0, Cogl.PipelineWrapMode.CLAMP_TO_EDGE);

        pipeline = new Cogl.Pipeline (ctx);
        pipeline.set_layer_null_texture (0);
        pipeline.set_layer_filters (0, Cogl.PipelineFilter.LINEAR, Cogl.PipelineFilter.LINEAR);
        pipeline.set_layer_wrap_mode (0, Cogl.PipelineWrapMode.CLAMP_TO_EDGE);

        background_pipeline = new Cogl.Pipeline (ctx);
        background_pipeline.set_layer_null_texture (0);
        background_pipeline.set_layer_filters (0, Cogl.PipelineFilter.LINEAR, Cogl.PipelineFilter.LINEAR);
        background_pipeline.set_layer_wrap_mode (0, Cogl.PipelineWrapMode.CLAMP_TO_EDGE);
    }

    private bool needs_repaint (Clutter.EffectPaintFlags flags) {
        if (mode == BlurMode.BLUR_ACTOR) {
            var actor_dirty = (flags & Clutter.EffectPaintFlags.ACTOR_DIRTY) != 0;

            return actor_dirty || !blur_applied || !actor_painted;
        }

        return true;
    }

    private Clutter.ActorBox update_actor_box (Clutter.PaintContext paint_context) {
        Clutter.ActorBox actor_box;

        if (mode == BlurMode.BLUR_ACTOR) {
            actor_box = actor.get_allocation_box ();
        } else {
            var stage_view = paint_context.get_stage_view ();

            float origin_x, origin_y, width, height;
            actor.get_transformed_position (out origin_x, out origin_y);
            actor.get_transformed_size (out width, out height);

            var box_scale_factor = 1.0f;
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

            actor_box = Clutter.ActorBox ();
            actor_box.set_origin (origin_x, origin_y);
            actor_box.set_size (width, height);
            actor_box.scale (box_scale_factor);
        }

        Clutter.ActorBox.clamp_to_pixel (ref actor_box);

        return actor_box;
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

    private void setup_projection_matrix (Cogl.Framebuffer framebuffer, float width, float height) {
        Graphene.Matrix projection = {};
        projection.init_translate ({ -width / 2.0f, -height / 2.0f, 0.0f });
        projection.scale (2.0f / width, -2.0f / height, 1.0f);

        framebuffer.set_projection_matrix (projection);
    }

    private bool update_general_fbo (int width, int height, float downscale_factor) {
        if (
            texture_width == width &&
            texture_height == height &&
            this.downscale_factor == downscale_factor &&
            framebuffer != null
        ) {
            return true;
        }

        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();

        framebuffer = null;
        texture = null;

        var new_width = (int) Math.floorf (width / downscale_factor);
        var new_height = (int) Math.floorf (height / downscale_factor);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, new_width, new_height);

        try {
            texture = new Cogl.Texture2D.from_data (ctx, new_width, new_height, Cogl.PixelFormat.BGRA_8888_PRE, surface.get_stride (), surface.get_data ());
        } catch (GLib.Error e) {
            warning (e.message);
            return false;
        }

        pipeline.set_layer_texture (0, texture);

        framebuffer = new Cogl.Offscreen.with_texture (texture);

        setup_projection_matrix (framebuffer, new_width, new_height);

        return true;
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

        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();

        actor_framebuffer = null;
        actor_texture = null;

        var new_width = (int) Math.floorf (width / downscale_factor);
        var new_height = (int) Math.floorf (height / downscale_factor);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, new_width, new_height);

        try {
            actor_texture = new Cogl.Texture2D.from_data (ctx, new_width, new_height, Cogl.PixelFormat.BGRA_8888_PRE, surface.get_stride (), surface.get_data ());
        } catch (GLib.Error e) {
            warning (e.message);
            return false;
        }

        actor_pipeline.set_layer_texture (0, actor_texture);

        actor_framebuffer = (Cogl.Framebuffer) new Cogl.Offscreen.with_texture (actor_texture);

        setup_projection_matrix (actor_framebuffer, new_width, new_height);

        return true;
    }

    private bool update_background_fbo (int width, int height, float downscale_factor) {
        if (texture_width == width &&
            texture_height == height &&
            background_framebuffer != null
        ) {
            return true;
        }

        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();

        background_framebuffer = null;
        background_texture = null;

        var new_width = (int) Math.floorf (width / downscale_factor);
        var new_height = (int) Math.floorf (height / downscale_factor);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, new_width, new_height);

        try {
            background_texture = new Cogl.Texture2D.from_data (ctx, new_width, new_height, Cogl.PixelFormat.BGRA_8888_PRE, surface.get_stride (), surface.get_data ());
        } catch (GLib.Error e) {
            warning (e.message);
            return false;
        }

        background_pipeline.set_layer_texture (0, background_texture);

        background_framebuffer = (Cogl.Framebuffer) new Cogl.Offscreen.with_texture (background_texture);

        setup_projection_matrix (background_framebuffer, new_width, new_height);

        return true;
    }

    private bool update_framebuffers (Clutter.PaintContext paint_context, Clutter.ActorBox actor_box) {
        var width = (int) actor_box.get_width ();
        var height = (int) actor_box.get_height ();

        var downscale_factor = calculate_downscale_factor (width, height, radius);

        var updated = update_actor_fbo (width, height, downscale_factor) && update_general_fbo (width, height, downscale_factor);

        if (mode == BlurMode.BLUR_BACKGROUND) {
            updated = updated && update_background_fbo (width, height, downscale_factor);
        }

        texture_width = width;
        texture_height = height;
        this.downscale_factor = downscale_factor;

        return updated;
    }

    private Clutter.PaintNode create_blur_nodes (Clutter.PaintNode node) {
        float width, height;
        actor.get_size (out width, out height);

        var general_node = new Clutter.LayerNode.to_framebuffer (framebuffer, pipeline);
        node.add_child (general_node);
        general_node.add_rectangle ({ 0.0f, 0.0f, width, height });

        var blur_node = new Clutter.BlurNode (
            (uint) (texture_width / downscale_factor),
            (uint) (texture_height / downscale_factor),
            radius / downscale_factor
        );
        general_node.add_child (blur_node);
        blur_node.add_rectangle ({
            0.0f,
            0.0f,
            texture.get_width (),
            texture.get_height ()
        });

        blur_applied = true;

        return blur_node;
    }


    private void paint_background (Clutter.PaintNode node, Clutter.PaintContext paint_context, Clutter.ActorBox actor_box) {
        float transformed_x, transformed_y, transformed_width, transformed_height;

        actor_box.get_origin (out transformed_x, out transformed_y);
        actor_box.get_size (out transformed_width, out transformed_height);

        /* Background layer node */
        var background_node = new Clutter.LayerNode.to_framebuffer (background_framebuffer, background_pipeline);
        node.add_child (background_node);
        background_node.add_rectangle ({
            0.0f,
            0.0f,
            texture_width / downscale_factor,
            texture_height / downscale_factor
        });

        /* Blit node */
        unowned var src = paint_context.get_framebuffer ();
        var blit_node = new Clutter.BlitNode (src);
        background_node.add_child (blit_node);
        blit_node.add_blit_rectangle ((int) transformed_x, (int) transformed_y, 0, 0, (int) transformed_width, (int) transformed_height);
    }

    private void paint_actor_offscreen (Clutter.PaintNode node, Clutter.EffectPaintFlags flags) {
        var actor_dirty = (flags & Clutter.EffectPaintFlags.ACTOR_DIRTY) != 0;

        /* The actor offscreen framebuffer is updated already */
        if (actor_dirty || !actor_painted) {
            /* Layer node */
            var layer_node = new Clutter.LayerNode.to_framebuffer (actor_framebuffer, actor_pipeline);
            node.add_child (layer_node);
            layer_node.add_rectangle ({
                0.0f,
                0.0f,
                texture_width / downscale_factor,
                texture_height / downscale_factor
            });

            /* Transform node */
            Graphene.Matrix transform = {};
            transform.init_scale (
                1.0f / downscale_factor,
                1.0f / downscale_factor,
                1.0f
            );
            var transform_node = new Clutter.TransformNode (transform);
            layer_node.add_child (transform_node);

            /* Actor node */
            add_actor_node (transform_node);

            actor_painted = true;
        } else {
            Clutter.PaintNode pipeline_node = null;

            pipeline_node = new Clutter.PipelineNode (actor_pipeline);
            node.add_child (pipeline_node);
            pipeline_node.add_rectangle ({
                0.0f,
                0.0f,
                texture_width / downscale_factor,
                texture_height / downscale_factor,
            });
        }
    }

    private void add_actor_node (Clutter.PaintNode node) {
        var actor_node = new Clutter.ActorNode (actor, 255);
        node.add_child (actor_node);
    }

    private void add_blurred_pipeline (Clutter.PaintNode node) {
        Clutter.PaintNode pipeline_node = null;
        float width, height;

        /* Use the untransformed actor size here, since the framebuffer itself already
        * has the actor transform matrix applied.
        */
        actor.get_size (out width, out height);

        pipeline_node = new Clutter.PipelineNode (pipeline);
        node.add_child (pipeline_node);

        pipeline_node.add_rectangle ({ 0.0f, 0.0f, width, height });
    }

    public override void paint_node (Clutter.PaintNode node, Clutter.PaintContext paint_context, Clutter.EffectPaintFlags flags) {
        if (radius <= 0) {
            // fallback to drawing actor
            add_actor_node (node);
            return;
        }

        var paint_opacity = 255;
        if (mode == BlurMode.BLUR_ACTOR) {
            paint_opacity = actor.get_paint_opacity ();
        }

        if (needs_repaint (flags)) {
            var actor_box = update_actor_box (paint_context);

            if (!update_framebuffers (paint_context, actor_box)) {
                // fallback to drawing actor
                add_actor_node (node);
                return;
            }

            var blur_node = create_blur_nodes (node);

            if (mode == BlurMode.BLUR_ACTOR) {
                paint_actor_offscreen (blur_node, flags);
            } else {
                paint_background (blur_node, paint_context, actor_box);
            }
        } else {
            /* Use the cached pipeline if no repaint is needed */
            add_blurred_pipeline (node);
        }

        if (mode == BlurMode.BLUR_BACKGROUND) {
            add_actor_node (node);
        }
    }
}
