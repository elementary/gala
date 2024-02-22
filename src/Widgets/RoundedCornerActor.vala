public class Gala.RoundedCornerActor : Clutter.Actor {
    public int border_radius { get; set; }
    public new Clutter.Color? background_color { get; set; }

    private Cogl.Pipeline pipeline;
    private Cairo.ImageSurface cached_surface;
    private Cairo.Context cached_context;
    private Cogl.Texture2D cached_texture;
    private int last_width;
    private int last_height;

    construct {
        pipeline = new Cogl.Pipeline (Clutter.get_default_backend ().get_cogl_context ());
    }

    public override void paint (Clutter.PaintContext context) {
        if (background_color == null) {
            base.paint (context);
            return;
        }

        if (cached_surface == null || last_width != (int) width || last_height != (int) height) {
            cached_texture = null;

            cached_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, (int) width, (int) height);
            cached_context = new Cairo.Context (cached_surface);
            last_width = (int) width;
            last_height = (int) height;
        }

        var surface = cached_surface;
        var ctx = cached_context;

        ctx.set_source_rgba (background_color.red, background_color.green, background_color.blue, background_color.alpha);
        Drawing.Utilities.cairo_rounded_rectangle (ctx, 0, 0, width, height, border_radius);
        ctx.set_operator (Cairo.Operator.SOURCE);
        ctx.fill ();
        ctx.restore ();
        ctx.paint ();

        try {
            if (cached_texture == null) {
                var texture = new Cogl.Texture2D.from_data (
                    context.get_framebuffer ().get_context (),
                    (int) width, (int) height,
                    Cogl.PixelFormat.BGRA_8888_PRE,
                    surface.get_stride (), surface.get_data ()
                );

                pipeline.set_layer_texture (0, texture);
                cached_texture = texture;
            }
        } catch (Error e) {
            debug (e.message);
        }

        var actual_opacity = get_paint_opacity () > background_color.alpha ? background_color.alpha : get_paint_opacity ();

        var color = Cogl.Color.from_4ub (background_color.red, background_color.green, background_color.blue, actual_opacity);
        color.premultiply ();

        pipeline.set_color (color);

        unowned var fb = context.get_framebuffer ();
        fb.draw_rectangle (pipeline, 0, 0, width, height);

        base.paint (context);
    }
}
