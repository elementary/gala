/*
 * Copyright 2024 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.RoundedCornersEffect : Clutter.ShaderEffect {
    private float x1;
    private float y1;
    private float x2;
    private float y2;

    public float clip_radius {
        construct set {
            warning ("Set clip_radius: %f", value);
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

            update_pixel_step ();
        }
    }

    public void set_bounds (float _x1, float _y1, float _x2, float _y2) {
        x1 = _x1;
        y1 = _y1;
        x2 = _x2;
        y2 = _y2;

        warning ("Set bounds: %f %f %f %f", x1, y1, x2, y2);
        set_uniform_value ("x1", x1);
        set_uniform_value ("y1", y1);
        set_uniform_value ("x2", x2);
        set_uniform_value ("y2", y2);

        update_pixel_step ();
    }

    public RoundedCornersEffect (float x1, float y1, float x2, float y2, float clip_radius, float monitor_scale) {
        Object (
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER,
            clip_radius: clip_radius,
            monitor_scale: monitor_scale
        );

        set_bounds (x1, y1, x2, y2);
    }

    construct {
        try {
            var bytes = GLib.resources_lookup_data ("/io/elementary/desktop/gala/shaders/rounded-corners.vert", GLib.ResourceLookupFlags.NONE);
            set_shader_source ((string) bytes.get_data ());
        } catch (Error e) {
            critical ("Unable to load rounded-corners.vert: %s", e.message);
        }
    }

    private void update_pixel_step () {
        warning ("Set pixel_Step: %f %f", 1.0f / ((x2 - x1) * monitor_scale), 1.0f / ((y2 - y1) * monitor_scale));
        set_uniform_value ("pixel_step_x", 1.0f / ((x2 - x1) * monitor_scale));
        set_uniform_value ("pixel_step_y", 1.0f / ((y2 - y1) * monitor_scale));
    }
}
