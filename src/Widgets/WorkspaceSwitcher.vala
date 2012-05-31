
public class WorkspaceSwitcher : Clutter.Group {
    
    public float len;
    
    Clutter.CairoTexture bg;
    Clutter.CairoTexture cur;
    
    int _workspaces = 1;
    public int workspaces {
        get {return _workspaces;}
        set {_workspaces = value; this.height = len*_workspaces+spacing;}
    }
    int _workspace = 0;
    public int workspace {
        get {return _workspace;}
        set {
            _workspace = value;
            cur.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 300, y:_workspace*len+1+spacing);
        }
    }
    
    int spacing = 10;
    float WIDTH = 200;
    
    Gala.Plugin plugin;
    
    public WorkspaceSwitcher (Gala.Plugin plugin, int w, int h) {
        
        this.plugin = plugin;
        
        this.height = 100+spacing*2;
        this.width  = WIDTH+spacing*2;
        this.opacity = 0;
        
        this.bg = new Clutter.CairoTexture (100, (int)WIDTH);
        this.bg.auto_resize = true;
        
        len = (float)(h)/w*WIDTH;
        this.bg.draw.connect ( (ctx) => {
            Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 0.5, 0.5, width-1, 
                height-1, 10);
            ctx.set_line_width (1);
            ctx.set_source_rgba (0, 0, 0, 0.5);
            ctx.stroke_preserve ();
            ctx.set_source_rgba (1, 1, 1, 0.4);
            ctx.fill ();
            
            for (var i=0;i<workspaces;i++) {
                Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 0.5+spacing, 
                    i*len+0.5+spacing, width-1-spacing*2, len-1-spacing, 10);
                ctx.set_line_width (1);
                ctx.set_source_rgba (0, 0, 0, 0.8);
                ctx.stroke_preserve ();
                ctx.set_source_rgba (0, 0, 0, 0.4);
                ctx.fill ();
            }
            return true;
        });
        
        this.cur = new Clutter.CairoTexture (100, 100);
        this.cur.width = width-1-spacing*2;
        this.cur.height = len-1-spacing;
        this.cur.x = spacing+1;
        this.cur.auto_resize = true;
        this.cur.draw.connect ( (ctx) => {
            Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 0.5, 0.5, cur.width-2, 
                cur.height-1, 10);
            ctx.set_line_width (1);
            ctx.set_source_rgba (0, 0, 0, 0.9);
            ctx.stroke_preserve ();
            ctx.set_source_rgba (1, 1, 1, 0.9);
            ctx.fill ();
            
            return true;
        });
        this.workspace = 0;
        
        this.add_child (bg);
        this.add_child (cur);
        bg.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.WIDTH, 0));
        bg.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.HEIGHT, 0));
        
        this.key_release_event.connect ( (e) => {
            if (((e.modifier_state & Clutter.ModifierType.MOD1_MASK) == 0) || 
                e.keyval == Clutter.Key.Alt_L) {
                
                plugin.end_modal ();
                this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity:0);
                
                return true;
            }
            return false;
        });
        this.key_press_event.connect ( (e) => {
            switch (e.keyval) {
                case Clutter.Key.Up:
                    this.workspace = plugin.move_workspaces (true);
                    return false;
                case Clutter.Key.Down:
                    this.workspace = plugin.move_workspaces (false);
                    return false;
                default:
                    return true;
            }
        });
    }
}
