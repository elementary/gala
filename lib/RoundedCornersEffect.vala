/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

public class Gala.RoundedCornersEffect : Clutter.OffscreenEffect {
    public int clip_radius { get; construct; }
    public float monitor_scale { get; construct set; }

    private int offset_location;
    private int actor_size_location;
    private int full_texture_size_location;
    private int clip_radius_location;

    public RoundedCornersEffect (int clip_radius, float monitor_scale) {
        Object (clip_radius: clip_radius, monitor_scale: monitor_scale);
    }

    construct {
        notify["monitor-scale"].connect (queue_repaint);
    }

    public override Cogl.Pipeline create_pipeline (Cogl.Texture texture) {
        var snippet = new Cogl.Snippet (
            Cogl.SnippetHook.FRAGMENT,
            """
            uniform sampler2D tex;
            uniform vec2 offset; 
            uniform vec2 actor_size;
            uniform vec2 full_texture_size;
            uniform int clip_radius;

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
            null
        );
        snippet.set_replace (
            """
            vec4 sample = texture2D (tex, cogl_tex_coord0_in.xy);

            vec2 texture_coord = cogl_tex_coord0_in.xy * full_texture_size;
            if (texture_coord.x < offset.x || texture_coord.x > offset.x + actor_size.x ||
                texture_coord.y < offset.y || texture_coord.y > offset.y + actor_size.y
            ) {
                cogl_color_out = vec4(0, 0, 0, 0);
                return;
            }

            texture_coord.x -= offset.x;
            texture_coord.y -= offset.y;
            cogl_color_out = sample * cogl_color_in * rounded_rect_coverage (texture_coord);
            """
        );

#if HAS_MUTTER47
        unowned var cogl_context = actor.context.get_backend ().get_cogl_context ();
#else
        unowned var cogl_context = Clutter.get_default_backend ().get_cogl_context ();
#endif

        var pipeline = new Cogl.Pipeline (cogl_context);
        pipeline.set_layer_texture (0, texture);
        pipeline.add_snippet (snippet);

        offset_location = pipeline.get_uniform_location ("offset");
        actor_size_location = pipeline.get_uniform_location ("actor_size");
        full_texture_size_location = pipeline.get_uniform_location ("full_texture_size");
        clip_radius_location = pipeline.get_uniform_location ("clip_radius");

        return pipeline;
    }

    public override void paint_target (Clutter.PaintNode node, Clutter.PaintContext paint_context) {
        float texture_width, texture_height;
        get_target_size (out texture_width, out texture_height);

        var resource_scale = actor.get_resource_scale ();

        var actor_box = actor.get_allocation_box ();
        actor_box.scale (resource_scale);
        var effect_box = actor_box.copy ();
        clutter_actor_box_enlarge_for_effects (ref effect_box);

        var offset_x = Math.ceilf ((actor_box.x1 - effect_box.x1) * resource_scale);
        var offset_y = Math.ceilf ((actor_box.y1 - effect_box.y1) * resource_scale);

        unowned var pipeline = get_pipeline ();
        pipeline.set_uniform_float (offset_location, 2, 1, { offset_x, offset_y });
        pipeline.set_uniform_float (actor_size_location, 2, 1, { Math.ceilf (actor_box.get_width ()), Math.ceilf (actor_box.get_height ()) });
        pipeline.set_uniform_float (full_texture_size_location, 2, 1, { texture_width, texture_height });
        pipeline.set_uniform_1i (clip_radius_location, Utils.scale_to_int (clip_radius, monitor_scale));

        base.paint_target (node, paint_context);
    }

    /**
     * This is the same as mutter's private _clutter_actor_box_enlarge_for_effects function
     * Mutter basically enlarges the texture a bit to "determine a stable quantized size in pixels
     * that doesn't vary due to the original box's sub-pixel position."
     *
     * We need to account for this in our shader code so this function is reimplemented here.
     */
    private void clutter_actor_box_enlarge_for_effects (ref Clutter.ActorBox box) {
        if (box.get_area () == 0.0) {
            return;
        }

        var width = box.x2 - box.x1;
        var height = box.y2 - box.y1;
        width = Math.nearbyintf (width);
        height = Math.nearbyintf (height);

        box.x2 = Math.ceilf (box.x2 + 0.75f);
        box.y2 = Math.ceilf (box.y2 + 0.75f);

        box.x1 = box.x2 - width - 3;
        box.y1 = box.y2 - height - 3;
    }
}
