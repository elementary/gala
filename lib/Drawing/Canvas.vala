private class Gala.Drawing.CanvasProxy : GLib.Object {
    private Clutter.Canvas canvas;

    construct {
        canvas = new Clutter.Canvas ();
        canvas.draw.connect (on_draw);
    }

    public bool get_preferred_size (out float out_width, out float out_height) {
        return canvas.get_preferred_size (out out_width, out out_height);
    }

    public void invalidate () {
        canvas.invalidate ();
    }

    public void invalidate_size () {
        canvas.invalidate_size ();
    }

    public void paint_content (Clutter.Actor actor, Clutter.PaintNode root, Clutter.PaintContext paint_context) {
        canvas.paint_content (actor, root, paint_context);
    }

    public void set_size (int new_width, int new_height) requires (new_width >= -1 && new_height >= -1) {
        canvas.set_size (new_width, new_height);
    }

    public void set_scale_factor (float new_scale_factor) requires (new_scale_factor > 0.0f) {
        canvas.set_scale_factor (new_scale_factor);
    }

    private bool on_draw (Cairo.Context cr, int width, int height) {
        draw (cr, width, height, canvas.get_scale_factor ());
        return true;
    }

    public virtual signal void draw (Cairo.Context cr, int width, int height, float scale_factor);
}


public class Gala.Drawing.Canvas : GLib.Object, Clutter.Content {
    public float scale_factor {
        set {
            canvas.set_scale_factor (value);
        }
    }
    private CanvasProxy canvas;

    construct {
        canvas = new CanvasProxy ();
        canvas.draw.connect (on_draw);
    }

    public bool get_preferred_size (out float out_width, out float out_height) {
        return canvas.get_preferred_size (out out_width, out out_height);
    }

    public void invalidate () {
        canvas.invalidate ();
    }

    public void invalidate_size () {
        canvas.invalidate_size ();
    }

    public void paint_content (Clutter.Actor actor, Clutter.PaintNode root, Clutter.PaintContext paint_context) {
        canvas.paint_content (actor, root, paint_context);
    }

    public void set_size (int new_width, int new_height) requires (new_width >= -1 && new_height >= -1) {
        canvas.set_size (new_width, new_height);
    }

    private void on_draw (Cairo.Context cr, int width, int height, float scale_factor) {
        draw (cr, width, height, scale_factor);
    }

    public virtual signal void draw (Cairo.Context cr, int width, int height, float scale_factor);
}
