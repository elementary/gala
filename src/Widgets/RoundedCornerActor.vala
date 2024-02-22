public class Gala.RoundedCornerActor : Clutter.Actor {
    private Cogl.Pipeline pipeline;
    private Cairo.ImageSurface cached_surface;
    private Cairo.Context cached_context;
    private Cogl.Texture2D cached_texture;
    private int last_width;
    private int last_height;

    construct {
        pipeline = new Cogl.Pipeline (Clutter.get_default_backend ().get_cogl_context ());

        reactive = true;
    }

    public override void paint (Clutter.PaintContext context) {
        base.paint (context);

        if (cached_surface == null || last_width != (int) width || last_height != (int) height) {
            cached_texture = null;

            cached_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, (int) width, (int) height);
            cached_context = new Cairo.Context (cached_surface);
            last_width = (int) width;
            last_height = (int) height;
        }

        var surface = cached_surface;
        var ctx = cached_context;

        ctx.set_source_rgba (255, 255, 255, get_paint_opacity ());
        Drawing.Utilities.cairo_rounded_rectangle (ctx, 0, 0, width, height, 9);
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

        var color = Cogl.Color.from_4ub (255, 255, 255, get_paint_opacity ());
        color.premultiply ();

        pipeline.set_color (color);

        //  var radius = 5;
        //  var width_without_radius = width - 2 * radius;
        //  float[] rects = {radius, radius, }

        unowned var fb = context.get_framebuffer ();
        fb.draw_rectangle (pipeline, 0, 0, width, height);
    }
}
