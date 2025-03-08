// TODO: Copyright

public class Gala.CircularProgressbar : Clutter.Actor {
    public uint radius { get; set; default = 0; }
    public uint duration { get; set; default = 0; }
    public float monitor_scaling_factor { get; set; default = 1.0f; }
    public double angle { get; set; default = START_ANGLE; }

    private const double BACKGROUND_OPACITY = 0.7;
    private const int BORDER_WIDTH_PX = 1;
    private const double START_ANGLE = 3 * Math.PI_2;

    private Cogl.Pipeline pipeline;
    private Clutter.PropertyTransition transition;
    private Cairo.ImageSurface? surface;
    private uint diameter { get { return radius * 2; }}

    construct {
        visible = false;
        reactive = false;

#if HAS_MUTTER47
        unowned var backend = context.get_backend ();
#else
        unowned var backend = Clutter.get_default_backend ();
#endif
        pipeline = new Cogl.Pipeline (backend.get_cogl_context ());

        transition = new Clutter.PropertyTransition ("angle");
        transition.set_progress_mode (Clutter.AnimationMode.LINEAR);
        transition.set_animatable (this);
        transition.set_from_value (START_ANGLE);
        transition.set_to_value (START_ANGLE + 2 * Math.PI);

        transition.new_frame.connect (() => {
            queue_redraw ();
        });
    }

    public void start () {
        visible = true;
        width = diameter;
        height = diameter;

        if (surface == null || surface.get_width () != diameter || surface.get_height () != diameter) {
            surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, (int) diameter, (int) diameter);
        }

        transition.duration = duration;
        transition.start ();
    }

    public void reset () {
        visible = false;
        transition.stop ();
    }

    public override void paint (Clutter.PaintContext context) {
        if (angle == START_ANGLE) {
            return;
        }

        var rgba = Drawing.StyleManager.get_instance ().theme_accent_color;

        /* Don't use alpha from the stylesheet to ensure contrast */
        var stroke_color = new Cairo.Pattern.rgb (rgba.red, rgba.green, rgba.blue);
        var fill_color = new Cairo.Pattern.rgba (rgba.red, rgba.green, rgba.blue, BACKGROUND_OPACITY);

        var border_width = InternalUtils.scale_to_int (BORDER_WIDTH_PX, monitor_scaling_factor);

        var cr = new Cairo.Context (surface);

        // Clear the surface
        cr.save ();
        cr.set_source_rgba (0, 0, 0, 0);
        cr.set_operator (Cairo.Operator.SOURCE);
        cr.paint ();
        cr.restore ();

        cr.set_line_cap (Cairo.LineCap.ROUND);
        cr.set_line_join (Cairo.LineJoin.ROUND);
        cr.translate (radius, radius);

        cr.move_to (0, 0);
        cr.arc (0, 0, radius - border_width, START_ANGLE, angle);
        cr.line_to (0, 0);
        cr.close_path ();

        cr.set_line_width (0);
        cr.set_source (fill_color);
        cr.fill_preserve ();

        cr.set_line_width (border_width);
        cr.set_source (stroke_color);
        cr.stroke ();

        var cogl_context = context.get_framebuffer ().get_context ();

        try {
            var texture = new Cogl.Texture2D.from_data (
                cogl_context,
                (int) diameter, (int) diameter,
                Cogl.PixelFormat.BGRA_8888_PRE,
                surface.get_stride (), surface.get_data ()
            );

            pipeline.set_layer_texture (0, texture);

            context.get_framebuffer ().draw_rectangle (pipeline, 0, 0, diameter, diameter);
        } catch (Error e) {
            warning ("CircularProgressbar: Couldn't create new texture: %s", e.message);
        }

        base.paint (context);
    }
}
