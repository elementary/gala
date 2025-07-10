/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.RoundedCornersEffect : Clutter.ShaderEffect {
    private const int CLIP_RADIUS_OFFSET = 3;

    public float clip_radius {
        construct set {
            set_uniform_value ("clip_radius",  value + CLIP_RADIUS_OFFSET);
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
                update_actor_size ();
            }
        }
    }

    public RoundedCornersEffect (float clip_radius, float monitor_scale) {
        Object (
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER,
            clip_radius: clip_radius,
            monitor_scale: monitor_scale
        );
    }

    construct {
        try {
            var bytes = GLib.resources_lookup_data ("/io/elementary/desktop/gala/shaders/rounded-corners.vert", GLib.ResourceLookupFlags.NONE);
            set_shader_source ((string) bytes.get_data ());
        } catch (Error e) {
            critical ("Unable to load rounded-corners.vert: %s", e.message);
        }
    }

    public override void set_actor (Clutter.Actor? actor) {
        base.set_actor (actor);

        if (actor == null) {
            return;
        }

        actor.notify["width"].connect (update_actor_size);
        actor.notify["height"].connect (update_actor_size);

        update_actor_size ();
    }

    private void update_actor_size () requires (actor != null) {
        float[] actor_size = {
            actor.width * monitor_scale,
            actor.height * monitor_scale
        };

        var actor_size_value = GLib.Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (actor_size_value, actor_size);
        set_uniform_value ("actor_size", actor_size_value);
    }
}
