/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

public class Gala.RoundedCornersEffect : Clutter.ShaderEffect {
    private int _clip_radius;
    public int clip_radius {
        get {
            return _clip_radius;
        }
        construct set {
            _clip_radius = value;

            if (actor != null) {
                update_clip_radius ();
            }
        }
    }

    private float _monitor_scale = 1.0f;
    public float monitor_scale {
        get {
            return _monitor_scale;
        }
        construct set {
            _monitor_scale = value;

            if (actor != null) {
                update_clip_radius ();
                update_actor_size ();
            }
        }
    }
    private static string decls = """
        // based on shader from mutter
        uniform sampler2D tex;
        uniform int clip_radius;
        uniform vec2 actor_size;
        uniform vec2 offset;
        uniform vec2 full_texture_size;

        float rounded_rect_coverage(vec2 p) {
            float center_left = clip_radius;
            float center_right = actor_size.x - clip_radius;

            float center_x;
            if (p.x < center_left)
                center_x = center_left;
            else if (p.x > center_right)
                center_x = center_right;
            else
                return 1.0;

            float center_top = clip_radius;
            float center_bottom = actor_size.y - clip_radius;

            float center_y;
            if (p.y < center_top)
                center_y = center_top;
            else if (p.y > center_bottom)
                center_y = center_bottom;
            else
                return 1.0;

            vec2 delta = p - vec2(center_x, center_y);
            float dist_squared = dot(delta, delta);

            // Fully outside the circle
            float outer_radius = clip_radius + 0.5;
            if (dist_squared > (outer_radius * outer_radius))
                return 0.0;

            // Fully inside the circle
            float inner_radius = clip_radius - 0.5;
            if (dist_squared < (inner_radius * inner_radius))
                return 1.0;

            // Only pixels on the edge of the curve need expensive antialiasing
            return smoothstep(outer_radius, inner_radius, sqrt(dist_squared));
        }
    """;

    private static string post = """
        vec2 texture_coord = cogl_tex_coord0_in.xy * full_texture_size;
        if (texture_coord.x < offset.x || texture_coord.x > offset.x + actor_size.x ||
            texture_coord.y < offset.y || texture_coord.y > offset.y + actor_size.y
        ) {
            cogl_color_out = vec4(0, 0, 0, 0);
            return;
        }

        texture_coord.x -= offset.x;
        texture_coord.y -= offset.y;

        vec4
        sample = texture2D(tex, cogl_tex_coord0_in.xy);
        float res = rounded_rect_coverage(texture_coord);
        cogl_color_out = sample * cogl_color_in * res;
    """;

    public RoundedCornersEffect (int clip_radius, float monitor_scale) {
        Object (
#if !HAS_MUTTER51
#if HAS_MUTTER48
            shader_type: Cogl.ShaderType.FRAGMENT,
#else
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER,
#endif
#endif
            clip_radius: clip_radius,
            monitor_scale: monitor_scale
        );
    }

    construct {
#if !HAS_MUTTER51
        set_shader_source (@"$decls \n void main() { $post }");
#endif
    }

#if HAS_MUTTER51
    public override Cogl.Snippet get_static_snippet () {
        return new Cogl.Snippet (Cogl.SnippetHook.FRAGMENT, decls, post);
    }
#endif

    public override void set_actor (Clutter.Actor? new_actor) {
        if (actor != null) {
            actor.notify["width"].disconnect (update_actor_size);
            actor.notify["height"].disconnect (update_actor_size);
        }

        base.set_actor (new_actor);

        if (actor != null) {
            actor.notify["width"].connect (update_actor_size);
            actor.notify["height"].connect (update_actor_size);

            update_clip_radius ();
            update_actor_size ();
        }
    }

    private void update_clip_radius () requires (actor != null) {
        set_uniform_value ("clip_radius", Utils.scale_to_int (clip_radius, monitor_scale));
    }

    private void update_actor_size () requires (actor != null) {
        var actor_box = actor.get_allocation_box ();
        Clutter.ActorBox.clamp_to_pixel (ref actor_box);

        float[] actor_size = {
            Math.ceilf (actor_box.get_width ()),
            Math.ceilf (actor_box.get_height ())
        };

        var actor_size_value = GLib.Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (actor_size_value, actor_size);
        set_uniform_value ("actor_size", actor_size_value);

        var effect_box = actor_box.copy ();
        clutter_actor_box_enlarge_for_effects (ref effect_box);

        float[] full_texture_size = {
            Math.ceilf (effect_box.get_width ()),
            Math.ceilf (effect_box.get_height ())
        };

        var full_texture_size_value = GLib.Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (full_texture_size_value, full_texture_size);
        set_uniform_value ("full_texture_size", full_texture_size_value);

        float[] offset = {
            Math.ceilf (actor_box.x1 - effect_box.x1),
            Math.ceilf (actor_box.y1 - effect_box.y1)
        };

        var offset_value = GLib.Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (offset_value, offset);
        set_uniform_value ("offset", offset_value);
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
        width = nearbyint (width);
        height = nearbyint (height);

        box.x2 = Math.ceilf (box.x2 + 0.75f);
        box.y2 = Math.ceilf (box.y2 + 0.75f);

        box.x1 = box.x2 - width - 3;
        box.y1 = box.y2 - height - 3;
    }

    /**
     * Mutter uses custom nearbyint macro instead of Math.nearbyintf
     */
    private int nearbyint (float x) {
        return (int) ((x) < 0.0f ? (x) - 0.5f : (x) + 0.5f);
    }
}
