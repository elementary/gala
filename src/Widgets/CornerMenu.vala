
public class CornerMenu : Clutter.Group {
    
    Clutter.Box     workspaces;
    
    unowned Gala.Plugin plugin;
    
    bool animating; //prevent closing of the popup too fast
    
    public CornerMenu (Gala.Plugin plugin) {
        
        this.plugin = plugin;
        
        this.width  = 100;
        this.height = 100;
        
        this.scale_gravity = Clutter.Gravity.SOUTH_EAST;
        this.opacity = 0;
        this.scale_x = this.scale_y = 0.0f;
        
        this.workspaces = new Clutter.Box (new Clutter.BoxLayout ());
        (this.workspaces.layout_manager as Clutter.BoxLayout).spacing = 15;
        (this.workspaces.layout_manager as Clutter.BoxLayout).vertical = true;
        
        this.reactive = true;
        this.leave_event.connect ( (e) => {
            if (this.get_children ().index (e.related) == -1)
                this.hide ();
            return false;
        });
        
        var tile = new GtkClutter.Texture ();
        try {
            tile.set_from_pixbuf (Gtk.IconTheme.get_default ().load_icon ("preferences-desktop-display", 64, 0));
        } catch (Error e) { warning (e.message); }
        tile.x = 5;
        tile.y = 5;
        tile.reactive = true;
        tile.button_release_event.connect ( () => {
            
            var windows = new GLib.List<Meta.Window> ();
            plugin.screen.get_active_workspace ().list_windows ().foreach ( (w) => {
                if (w.window_type != Meta.WindowType.NORMAL || w.minimized)
                    return;
                windows.append (w);
            });
            
            //make sure active window is biggest
            var active_idx = windows.index (plugin.screen.get_display ().get_focus_window ());
            if (active_idx != -1 && active_idx != 0) {
                windows.delete_link (windows.nth (active_idx));
                windows.prepend (plugin.screen.get_display ().get_focus_window ());
            }
            
            unowned Meta.Rectangle area;
            plugin.screen.get_active_workspace ().get_work_area_all_monitors (out area);
            
            var n_wins = windows.length ();
            var index  = 0;
            
            windows.foreach ( (w) => {
                if (w.maximized_horizontally || w.maximized_vertically)
                    w.unmaximize (Meta.MaximizeFlags.VERTICAL | Meta.MaximizeFlags.HORIZONTAL);
                switch (n_wins) {
                    case 1:
                        w.move_resize_frame (true, area.x, area.y, area.width, area.height);
                        break;
                    case 2:
                        w.move_resize_frame (true, area.x+area.width/2*index, area.y, area.width/2, 
                            area.height);
                        break;
                    case 3:
                        if (index == 0)
                            w.move_resize_frame (true, area.x, area.y, area.width/2, area.height);
                        else {
                            w.move_resize_frame (true, area.x+area.width/2, 
                                area.y+(area.height/2*(index-1)), area.width/2, area.height/2);
                        }
                        break;
                    case 4:
                        if (index < 2)
                            w.move_resize_frame (true, area.x+area.width/2*index, area.y, 
                                area.width/2, area.height/2);
                        else
                            w.move_resize_frame (true, (index==3)?area.x+area.width/2:area.x, 
                                area.y+area.height/2, area.width/2, area.height/2);
                        break;
                    case 5:
                        if (index < 2)
                            w.move_resize_frame (true, area.x, area.y+(area.height/2*index), 
                                area.width/2, area.height/2);
                        else
                            w.move_resize_frame (true, area.x+area.width/2, 
                                area.y+(area.height/3*(index-2)), area.width/2, area.height/3);
                        break;
                    case 6:
                        if (index < 3)
                            w.move_resize_frame (true, area.x, area.y+(area.height/3*index),
                                area.width/2, area.height/3);
                        else
                            w.move_resize_frame (true, area.x+area.width/2, 
                                area.y+(area.height/3*(index-3)), area.width/2, area.height/3);
                        break;
                    default:
                        return;
                }
                index ++;
            });
            return true;
        });
        
        this.add_child (tile);
        //this.add_child (this.workspaces);
    }
    
    public new void show () {
        if (this.visible)
            return;
        plugin.set_input_area (Gala.InputArea.FULLSCREEN);
        plugin.begin_modal ();
        
        animating = true;
        
        int width, height;
        plugin.get_screen ().get_size (out width, out height);
        this.x = width  - this.width;
        this.y = height - this.height;
        
        this.visible = true;
        this.grab_key_focus ();
        this.animate (Clutter.AnimationMode.EASE_OUT_BOUNCE, 400, scale_x:1.0f, scale_y:1.0f, opacity:255).completed.connect ( () => {
            animating = false;
        });
        
        /*for (var i=0;i<plugin.get_screen ().n_workspaces;i++) {
            plugin.get_screen ().get_workspace_by_index (i);
            
            var g = new Clutter.Group ();
            
            var s = new Clutter.Rectangle.with_color ({0, 0, 0, 255});
            var b = new Clutter.Clone (background);
            
            b.width  = s.width  = WIDTH;
            b.height = s.height = HEIGHT;
            
            g.add_child (s);
            g.add_child (b);
            
            this.workspaces.add_child (g);
        }*/
    }
    
    public new void hide () {
        if (!this.visible || animating)
            return;
        
        plugin.end_modal ();
        plugin.set_input_area (Gala.InputArea.HOT_CORNER);
        
        this.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, scale_x:0.0f, scale_y:0.0f, opacity:0)
            .completed.connect ( () => {
            this.visible = false;
        });
    }
}
