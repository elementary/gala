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

    public RoundedCornersEffect (int clip_radius, float monitor_scale) {
        Object (
#if HAS_MUTTER48
            shader_type: Cogl.ShaderType.FRAGMENT,
#else
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER,
#endif
            clip_radius: clip_radius,
            monitor_scale: monitor_scale
        );
    }

    construct {
        try {
            var bytes = GLib.resources_lookup_data ("/io/elementary/desktop/gala/shaders/rounded-corners.frag", NONE);
            set_shader_source ((string) bytes.get_data ());
        } catch (Error e) {
            critical ("Unable to load rounded-corners.frag: %s", e.message);
        }
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

            update_clip_radius ();
            update_actor_size ();
        }
    }

    private void update_clip_radius () requires (actor != null) {
        var resource_scale = actor.get_resource_scale ();
        set_uniform_value ("clip_radius", Utils.scale_to_int (clip_radius, monitor_scale / resource_scale));
    }

    private void update_actor_size () requires (actor != null) {
        var resource_scale = actor.get_resource_scale ();
        var actor_box = actor.get_allocation_box ();
        actor_box.scale (1.0f / resource_scale);
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
            Math.ceilf ((actor_box.x1 - effect_box.x1)),
            Math.ceilf ((actor_box.y1 - effect_box.y1))
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
        width = Math.nearbyintf (width);
        height = Math.nearbyintf (height);

        box.x2 = Math.ceilf (box.x2 + 0.75f);
        box.y2 = Math.ceilf (box.y2 + 0.75f);

        box.x1 = box.x2 - width - 3;
        box.y1 = box.y2 - height - 3;
    }
}
