/*
 * Copyright 2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * {@link Clutter.Effect} implementation to apply shaders quickly and easily.
 * The main difference between Gala.SimpleShaderEffect and Clutter.ShaderEffect is that
 * we don't use {@link Clutter.OffscreenEffect} that enlarges the texture for fractional scaling which
 * can produce some graphical glitches.
 */
public abstract class Gala.SimpleShaderEffect : Clutter.Effect {
    /**
     * Fallback shader that outputs the original content.
     */
    public const string FALLBACK_SHADER = "uniform sampler2D tex; void main () { cogl_color_out = texture2D (tex, cogl_tex_coord0_in.xy); }";

    private Cogl.Program program;
    private Cogl.Pipeline pipeline;
    private Cogl.Framebuffer framebuffer;
    private Cogl.Texture texture;
    private int texture_width;
    private int texture_height;

    protected SimpleShaderEffect (string shader_source) {
        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();

        var shader = Cogl.Shader.create (FRAGMENT);
        shader.source (shader_source);

        program = Cogl.Program.create ();
        program.attach_shader (shader);
        program.link ();

        pipeline = new Cogl.Pipeline (ctx);
        pipeline.set_user_program (program);
    }

    private bool update_framebuffer () {
        var actor_box = actor.get_allocation_box ();
        var new_width = (int) actor_box.get_width ();
        var new_height = (int) actor_box.get_height ();

        if (new_width <= 0 || new_height <= 0) {
            warning ("SimpleShaderEffect: Couldn't update framebuffers, incorrect size");
            return false;
        }

        if (texture_width == new_width && texture_height == new_height && framebuffer != null) {
            return true;
        }

        unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();

#if HAS_MUTTER46
        texture = new Cogl.Texture2D.with_size (ctx, new_width, new_height);
#else
        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, new_width, new_height);
        try {
            texture = new Cogl.Texture2D.from_data (ctx, new_width, new_height, Cogl.PixelFormat.BGRA_8888_PRE, surface.get_stride (), surface.get_data ());
        } catch (Error e) {
            critical ("SimpleShaderEffect: Couldn't create texture: %s", e.message);
            return false;
        }
#endif

        pipeline.set_layer_texture (0, texture);
        framebuffer = new Cogl.Offscreen.with_texture (texture);

        Graphene.Matrix projection = {};
        projection.init_translate ({ -new_width / 2.0f, -new_height / 2.0f, 0.0f });
        projection.scale (2.0f / new_width, -2.0f / new_height, 1.0f);

        framebuffer.set_projection_matrix (projection);

        texture_width = new_width;
        texture_height = new_height;

        return true;
    }

    public override void paint_node (Clutter.PaintNode node, Clutter.PaintContext paint_context, Clutter.EffectPaintFlags flags) {
        var actor_node = new Clutter.ActorNode (actor, 255);

        if (BYPASS_EFFECT in flags || !update_framebuffer ()) {
            node.add_child (actor_node);
            return;
        }

        var layer_node = new Clutter.LayerNode.to_framebuffer (framebuffer, pipeline);
        layer_node.add_rectangle ({0, 0, texture_width, texture_height});
        layer_node.add_child (actor_node);

        node.add_child (layer_node);
    }

    private bool get_and_validate_uniform_location (string uniform, out int uniform_location) {
        uniform_location = program.get_uniform_location (uniform);

        if (uniform_location == -1) {
            warning ("Can't update uniform '%s'", uniform);
            return false;
        }

        return true;
    }

    protected void set_uniform_1f (string uniform, float value) {
        int uniform_location;
        if (get_and_validate_uniform_location (uniform, out uniform_location)) {
            program.set_uniform_1f (uniform_location, value);
        }
    }

    protected void set_uniform_1i (string uniform, int value) {
        int uniform_location;
        if (get_and_validate_uniform_location (uniform, out uniform_location)) {
            program.set_uniform_1i (uniform_location, value);
        }
    }

    protected void set_uniform_float (string uniform, int n_components, float[] value) {
        int uniform_location;
        if (get_and_validate_uniform_location (uniform, out uniform_location)) {
            program.set_uniform_float (uniform_location, n_components, value);
        }
    }

    protected void set_uniform_int (string uniform, int n_components, int[] value) {
        int uniform_location;
        if (get_and_validate_uniform_location (uniform, out uniform_location)) {
            program.set_uniform_int (uniform_location, n_components, value);
        }
    }

    protected void set_uniform_matrix (string uniform, int dimensions, bool transpose, float[] value) {
        int uniform_location;
        if (get_and_validate_uniform_location (uniform, out uniform_location)) {
            program.set_uniform_matrix (uniform_location, dimensions, transpose, value);
        }
    }
}
