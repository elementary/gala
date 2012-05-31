
public class TextShadowEffect : Clutter.Effect {
    int _offset_y;
    public int offset_y {
        get { return _offset_y; }
        set { _offset_y = value; this.update (); }
    }
    int _offset_x;
    public int offset_x {
        get { return _offset_x; }
        set { _offset_x = value; this.update (); }
    }
    uint8 _opacity;
    public uint8 opacity {
        get { return _opacity; }
        set { _opacity = value; this.update (); }
    }
    
    public TextShadowEffect (int offset_x, int offset_y, uint8 opacity) {
        this._offset_x = offset_x;
        this._offset_y = offset_y;
        this._opacity  = opacity;
    }
    
    public override bool pre_paint () {
        var layout = ((Clutter.Text)this.get_actor ()).get_layout ();
        Cogl.pango_render_layout (layout, this.offset_x, this.offset_y, 
            Cogl.Color.from_4ub (0, 0, 0, opacity), 0);
        return true;
    }
    
    public void update () {
        if (this.get_actor () != null)
            this.get_actor ().queue_redraw ();
    }
}

namespace Gala {

    const string VERSION = "0.1";

    const string SCHEMA = "org.pantheon.desktop.gala";

    const OptionEntry[] OPTIONS = {
        { "version", 0, OptionFlags.NO_ARG, OptionArg.CALLBACK, (void*) print_version, "Print version", null },
        { null }
    };

    void print_version () {
        stdout.printf ("Gala %s\n", Gala.VERSION);
        Meta.exit (Meta.ExitCode.SUCCESS);
    }


}