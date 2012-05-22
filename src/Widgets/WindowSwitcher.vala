

public class WindowSwitcher : Clutter.Group {
    
    int ICON_SIZE = 96;
    int spacing   = 12;
    
    public float len;
    
    Clutter.CairoTexture bg;
    Clutter.CairoTexture cur;
    
    int _windows = 1;
    public int windows {
        get { return _windows; }
        set { _windows = value; this.width = spacing+_windows*(ICON_SIZE+spacing); }
    }
    
    public WindowSwitcher () {
        this.height = ICON_SIZE+spacing*2;
        this.opacity = 0;
        
        this.bg = new Clutter.CairoTexture (100, 100);
        this.bg.auto_resize = true;
        
        this.bg.draw.connect ( (ctx) => {
            Granite.Drawing.Utilities.cairo_rounded_rectangle (ctx, 0.5, 0.5, width-1, 
                height-1, 10);
            ctx.set_line_width (1);
            ctx.set_source_rgba (0, 0, 0, 0.5);
            ctx.stroke_preserve ();
            ctx.set_source_rgba (1, 1, 1, 0.4);
            ctx.fill ();
            
            return true;
        });
        
        this.cur = new Clutter.CairoTexture (ICON_SIZE, ICON_SIZE);
        this.cur.width = ICON_SIZE;
        this.cur.height = ICON_SIZE;
        this.cur.y = spacing+1;
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
        this.windows = 1;
        
        this.add_child (bg);
        this.add_child (cur);
        bg.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.WIDTH, 0));
        bg.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.HEIGHT, 0));
    }
    
    public void list_windows (List<Object> windows, Meta.Display dpy, bool backwards) {
        this.get_children ().foreach ( (c) => {
            if (c != cur && c != bg)
                this.remove_child (c);
        });
        
        var a = 0;
        var i = 0;
        windows.foreach ( (w) => {
            if ((w as Meta.Window).window_type != Meta.WindowType.NORMAL)
                return;
            var icon = new GtkClutter.Texture ();
            try {
                icon.set_from_pixbuf (((Meta.Window)w).icon);
            } catch (Error e) { warning (e.message); }
            icon.width = ICON_SIZE-10;
            icon.height = ICON_SIZE-10;
            icon.x = spacing+i*(spacing+ICON_SIZE)+5;
            icon.y = spacing+5;
            this.add_child (icon);
            
            if (w == dpy.focus_window)
                a = i;
            i ++;
        });
        this.windows = i;
        
        cur.x = spacing+a*(spacing+ICON_SIZE);
        if (!backwards) {
            a ++;
            if (a >= i)
                a = 0;
        } else {
            a --;
            if (a < 0)
                a = i;
        }
        cur.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, 
            x:0.0f+spacing+a*(spacing+ICON_SIZE)).completed.connect ( () => {
            this.animate (Clutter.AnimationMode.EASE_IN_QUAD, 800, opacity:0);
        });
        (windows.nth_data (a) as Meta.Window).activate (dpy.get_current_time ());
        
    }
}

