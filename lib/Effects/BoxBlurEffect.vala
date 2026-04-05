/*
 * Copyright 2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.BoxBlurEffect : Clutter.ShaderEffect {
    private enum PassDirection {
        HORIZONTAL = 1,
        VERTICAL = 2;
    }

    private const float[] HORIZONTAL_PASS_DATA = { 1.0f, 0.0f };
    private const float[] VERTICAL_PASS_DATA = { 0.0f, 1.0f };

    public int radius { set { set_uniform_value ("RADIUS", value); } }

    private BoxBlurEffect (int radius, PassDirection direction) {
        Object (
#if HAS_MUTTER48
            shader_type: Cogl.ShaderType.FRAGMENT
#else
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER
#endif
        );

        try {
            var bytes = GLib.resources_lookup_data ("/io/elementary/desktop/gala/shaders/box-blur.frag", NONE);
            set_shader_source ((string) bytes.get_data ());
        } catch (Error e) {
            critical ("Unable to load box-blur.frag: %s", e.message);
        }

        this.radius = radius;

        var direction_value = GLib.Value (typeof (Clutter.ShaderFloat));
        var direction_data = direction == HORIZONTAL ? HORIZONTAL_PASS_DATA : VERTICAL_PASS_DATA;
        Clutter.Value.set_shader_float (direction_value, direction_data);

        set_uniform_value ("DIRECTION", direction_value);
    }

    public static void apply_to_actor (Clutter.Actor actor, int radius) {
        actor.add_effect (new BoxBlurEffect (radius, HORIZONTAL));
        actor.add_effect (new BoxBlurEffect (radius, VERTICAL));
    }

    public override void set_actor (Clutter.Actor? new_actor) {
        if (actor != null) {
            actor.notify["width"].disconnect (update_pixel_step);
            actor.notify["height"].disconnect (update_pixel_step);
        }

        base.set_actor (new_actor);

        if (actor != null) {
            actor.notify["width"].connect (update_pixel_step);
            actor.notify["height"].connect (update_pixel_step);
            update_pixel_step ();
        }
    }

    private void update_pixel_step () {
        var pixel_step_value = GLib.Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (pixel_step_value, { 1 / actor.width, 1 / actor.height });

        set_uniform_value ("PIXEL_STEP", pixel_step_value);
    }
}
