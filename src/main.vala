
[CCode (cname="clutter_x11_handle_event")]
public extern int x_handle_event (X.Event xevent);

public class GalaPlugin : Meta.Plugin {
    public override void start () {
    }
    public override void minimize (Meta.WindowActor actor) {
        print ("MINIMIZE\n");
        this.minimize_completed (actor);
    }
    public override void maximize (Meta.WindowActor actor, int x, int y, int w, int h) {
        this.maximize_completed (actor);
    }
    public override void map (Meta.WindowActor actor) {
        actor.show ();
        switch (actor.meta_window.window_type) {
            case Meta.WindowType.NORMAL:
                actor.scale_gravity = Clutter.Gravity.CENTER;
                actor.scale_x = 0.0f;
                actor.scale_y = 0.0f;
                actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, 
                    scale_x:1.0f, scale_y:1.0f).completed.connect ( () => {
                    this.map_completed (actor);
                });
                break;
            case Meta.WindowType.MENU:
            case Meta.WindowType.DROPDOWN_MENU:
            case Meta.WindowType.POPUP_MENU:
                actor.scale_gravity = Clutter.Gravity.NORTH;
                actor.scale_x = 1.0f;
                actor.scale_y = 0.0f;
                actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, 
                    scale_y:1.0f).completed.connect ( () => {
                    this.map_completed (actor);
                });
                break;
            default:
                this.map_completed (actor);
                break;
        }
    }
    public override void destroy (Meta.WindowActor actor) {
        if (actor.meta_window.window_type == Meta.WindowType.NORMAL) {
            actor.scale_gravity = Clutter.Gravity.CENTER;
            actor.show ();
            actor.animate (Clutter.AnimationMode.EASE_IN_QUAD, 400, 
                scale_x:0.0f, scale_y:0.0f).completed.connect ( () => {
                this.destroy_completed (actor);
            });
        } else if (actor.meta_window.window_type == Meta.WindowType.MENU) {
            actor.scale_gravity = Clutter.Gravity.NORTH;
            actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, 
                scale_y:0.0f).completed.connect ( () => {
                this.map_completed (actor);
            });
        } else
            this.destroy_completed (actor);
    }
    public override void switch_workspace (int from, int to, Meta.MotionDirection direction) {
        /*var windows = Meta.get_window_actors (this.get_screen ());
        FIXME js/ui/windowManager.js line 430
        int w, h;
        this.get_screen ().get_size (out w, out h);
        
        var x2 = 0; var y2 = 0;
        if (direction == Meta.MotionDirection.UP ||
            direction == Meta.MotionDirection.UP_LEFT ||
            direction == Meta.MotionDirection.UP_RIGHT)
                y2 = h;
        else if (direction == Meta.MotionDirection.DOWN ||
                  direction == Meta.MotionDirection.DOWN_LEFT ||
                  direction == Meta.MotionDirection.DOWN_RIGHT)
                y2 = -h;
        
        if (direction == Meta.MotionDirection.LEFT ||
            direction == Meta.MotionDirection.UP_LEFT ||
            direction == Meta.MotionDirection.DOWN_LEFT)
                x2 = w;
        else if (direction == Meta.MotionDirection.RIGHT ||
                  direction == Meta.MotionDirection.UP_RIGHT ||
                  direction == Meta.MotionDirection.DOWN_RIGHT)
                x2 = -w;
        
        windows.foreach ( (w) => {
            if (!w.showing_on_its_workspace ())
                continue;
        });
        */
        this.switch_workspace_completed ();
    }
    public override void kill_window_effects (Meta.WindowActor actor){
        
    }
    public override void kill_switch_workspace () {
        
    }
    public override bool xevent_filter (X.Event event) {
        return x_handle_event (event) != 0;
    }
    
    public override Meta.PluginInfo plugin_info () {
        return {"Gala", "0.1", "Tom Beckmann", "GPLv3", "A nice window manager"};
    }
}

public static int main (string [] args) {
    Gtk.init (ref args);
    
    Meta.set_replace_current_wm (true);
    Meta.Plugin.type_register (new GalaPlugin ().get_type ());
    
    Meta.init ();
    
    return Meta.run ();
}

