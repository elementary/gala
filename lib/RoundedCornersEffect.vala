/*
 * Copyright 2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.RoundedCornersEffect : Clutter.ShaderEffect {
    public float clip_radius {
        construct set {
            set_uniform_value ("clip_radius",  value);
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
                update_pixel_step ();
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

        notify["actor"].connect (() => {
            if (actor == null) {
                return;
            }

            actor.notify["width"].connect (update_bounds);
            actor.notify["height"].connect (update_bounds);

            update_bounds ();
        });
    }

    private void update_bounds () requires (actor != null) {
        float[] bounds = {
            0.0f,
            0.0f,
            actor.width,
            actor.height
        };

        warning ("%f", actor.height);

        var bounds_value = GLib.Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (bounds_value, bounds);
        set_uniform_value ("bounds", bounds_value);

        update_pixel_step ();
    }

    private void update_pixel_step () requires (actor != null) {
        float[] pixel_step = {
            1.0f / (actor.width * monitor_scale),
            1.0f / (actor.height * monitor_scale)
        };

        var pixel_step_value = GLib.Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (pixel_step_value, pixel_step);
        set_uniform_value ("pixel_step", pixel_step_value);
    }
}
