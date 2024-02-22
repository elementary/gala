public class RoundedCornerEffect : Clutter.ShaderEffect {
    public RoundedCornerEffect () {
        Object (
            shader_type: Clutter.ShaderType.FRAGMENT_SHADER
        );
    }

    construct {
        try {
            var bytes = GLib.resources_lookup_data ("/io/elementary/desktop/gala/shaders/rounded-corners.frag", GLib.ResourceLookupFlags.NONE);
            set_shader_source ((string) bytes.get_data ());
        } catch (Error e) {
            critical ("Unable to load rounded-corner.vert: %s", e.message);
        }
    }

    public override void set_actor (Clutter.Actor? actor) {
        base.set_actor (actor);
        warning ("SET ACTOR");

        float border_width = 0;
        float radius = 10;

        float[] bounds = {actor.x, actor.y, actor.width, actor.height};
        float[] inner_bounds = {actor.x, actor.y, actor.width, actor.height};
        float[] pixel_step = {1.0f / actor.width, 1.0f / actor.height};

        float[] border_color = {0x2e, 0x34, 0x36, 0xff};
        float inner_radius = radius - border_width;

        var bounds_val = new Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (bounds_val, bounds);
        set_uniform_value ("bounds", bounds_val);

        var inner_bounds_val = new Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (inner_bounds_val, inner_bounds);
        set_uniform_value ("inner_bounds", inner_bounds_val);

        var pixel_step_val = new Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (pixel_step_val, pixel_step);
        set_uniform_value ("pixel_step", pixel_step_val);

        var border_color_val = new Value (typeof (Clutter.ShaderFloat));
        Clutter.Value.set_shader_float (border_color_val, border_color);
        set_uniform_value ("border_color", border_color_val);

        var radius_val = new Value (Type.FLOAT);
        radius_val.set_float (radius);
        set_uniform_value ("clip_radius", radius_val);

        var inner_radius_val = new Value (Type.FLOAT);
        inner_radius_val.set_float (inner_radius);
        set_uniform_value ("inner_clip_radius", inner_radius_val);

        var border_width_val = new Value (Type.FLOAT);
        border_width_val.set_float (border_width);
        set_uniform_value ("border_width", border_width_val);

        var exponent_val = new Value (Type.FLOAT);
        exponent_val.set_float (1);
        set_uniform_value ("exponent", exponent_val);

        queue_repaint ();
    }

    public override void paint_target (Clutter.PaintNode node, Clutter.PaintContext context) {
        base.paint_target (node, context);

        var pipeline = get_pipeline ();
        pipeline.set_blend ("RGBA = ADD (SRC_COLOR, DST_COLOR*(1-SRC_COLOR[A]))");

        var opacity_val = new Value (Type.FLOAT);
        opacity_val.set_float (actor.get_paint_opacity () / 255);
        set_uniform_value ("opacity", opacity_val);

        warning ("PAINT TARGET: %i", actor.get_paint_opacity ());
    }
}