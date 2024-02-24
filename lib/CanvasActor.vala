public class Gala.CanvasActor : Clutter.Actor {
    private Clutter.Canvas canvas;

    construct {
        canvas = new Clutter.Canvas ();
        content = canvas;
        canvas.draw.connect ((ctx, width, height) => {
            draw (ctx, width, height);
            return true;
        });
    }

    public override void resource_scale_changed () {
        canvas.set_scale_factor (get_resource_scale ());
    }

    public override void allocate (Clutter.ActorBox box) {
        base.allocate (box);
        canvas.set_size ((int)box.get_width (), (int)box.get_height ());
        canvas.set_scale_factor (get_resource_scale ());
    }

    protected virtual void draw (Cairo.Context canvas, int width, int height) { }
}
