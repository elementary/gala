
namespace Gala {
    
    public enum InputArea {
        FULLSCREEN,
        HOT_CORNER,
        NONE
    }
    
    public class Plugin : Meta.Plugin {
    
        public WorkspaceSwitcher wswitcher;
        public WindowSwitcher    winswitcher;
        public CornerMenu        corner_menu;
        public Clutter.Actor     elements;
        
        public Plugin () {
            if (Settings.get_default().use_gnome_defaults)
                return;
            Meta.Prefs.override_preference_schema ("attach-modal-dialogs", SCHEMA);
            Meta.Prefs.override_preference_schema ("button-layout", SCHEMA);
            Meta.Prefs.override_preference_schema ("edge-tiling", SCHEMA);
            Meta.Prefs.override_preference_schema ("enable-animations", SCHEMA);
            Meta.Prefs.override_preference_schema ("theme", SCHEMA);
        }
        
        public override void start () {
            
            this.elements = Meta.Compositor.get_stage_for_screen (screen);
            Meta.Compositor.get_window_group_for_screen (screen).reparent (elements);
            Meta.Compositor.get_overlay_group_for_screen (screen).reparent (elements);
            Meta.Compositor.get_stage_for_screen (screen).add_child (elements);
            
            screen.override_workspace_layout (Meta.ScreenCorner.TOPLEFT, false, -1, 4);
            
            int w, h;
            screen.get_size (out w, out h);
            
            this.corner_menu = new CornerMenu (this);
            this.elements.add_child (this.corner_menu);
            this.corner_menu.visible = false;
            
            this.wswitcher = new WorkspaceSwitcher (this, w, h);
            this.wswitcher.workspaces = 4;
            this.elements.add_child (this.wswitcher);
            
            this.winswitcher = new WindowSwitcher (this);
            this.elements.add_child (this.winswitcher);
            
            Meta.KeyBinding.set_custom_handler ("panel-main-menu", () => {
                try {
                    Process.spawn_command_line_async (
                        Settings.get_default().panel_main_menu_action);
                } catch (Error e) { warning (e.message); }
            });
            Meta.KeyBinding.set_custom_handler ("switch-windows", 
                (display, screen, window, ev, binding) => {
                window_switcher (display, screen, binding, false);
            });
            Meta.KeyBinding.set_custom_handler ("switch-windows-backward", 
                (display, screen, window, ev, binding) => {
                window_switcher (display, screen, binding, true);
            });
            Meta.KeyBinding.set_custom_handler ("switch-to-workspace-left",  ()=>{});
            Meta.KeyBinding.set_custom_handler ("switch-to-workspace-right", ()=>{});
            Meta.KeyBinding.set_custom_handler ("switch-to-workspace-up",    (d,s) => 
                workspace_switcher (s, true) );
            Meta.KeyBinding.set_custom_handler ("switch-to-workspace-down",  (d,s) =>
                workspace_switcher (s, false) );
            
            Meta.KeyBinding.set_custom_handler ("move-to-workspace-left",  ()=>{});
            Meta.KeyBinding.set_custom_handler ("move-to-workspace-right", ()=>{});
            Meta.KeyBinding.set_custom_handler ("move-to-workspace-up",    (d,s,w) => 
                move_window (w, true) );
            Meta.KeyBinding.set_custom_handler ("move-to-workspace-down",  (d,s,w) =>
                move_window (w, false) );
            
            /*shadows*/
            Meta.ShadowFactory.get_default ().set_params ("normal", true, {30, -1, 0, 35, 120});
            
            /*hot corner*/
            var hot_corner = new Clutter.Rectangle ();
            hot_corner.x        = w - 2;
            hot_corner.y        = h - 2;
            hot_corner.width    = 2;
            hot_corner.height   = 2;
            hot_corner.reactive = true;
            
            hot_corner.enter_event.connect ( () => {
                corner_menu.show ();
                return false;
            });
            
            Meta.Compositor.get_overlay_group_for_screen (screen).add_child (hot_corner);
            
            if (Settings.get_default ().enable_manager_corner)
                set_input_area (InputArea.HOT_CORNER);
            else
                set_input_area (InputArea.NONE);
            
            Settings.get_default ().notify["enable-manager-corner"].connect ( () => {
                if (Settings.get_default ().enable_manager_corner)
                    set_input_area (InputArea.HOT_CORNER);
                else
                    set_input_area (InputArea.NONE);
            });
        }
        
        /**
         * set the area where clutter can receive events
         **/
        public void set_input_area (InputArea area) {
            X.Rectangle rect;
            int width, height;
            
            screen.get_size (out width, out height);
            
            switch (area) {
                case InputArea.FULLSCREEN:
                    rect = {0, 0, (short)width, (short)height};
                    break;
                case InputArea.HOT_CORNER: //leave one pix in the bottom left
                    rect = {(short)(width - 1), (short)(height - 1), 1, 1};
                    break;
                default:
                    Meta.Util.empty_stage_input_region (screen);
                    return;
            }
            var xregion = X.Fixes.create_region (screen.get_display ().get_xdisplay (), {rect});
            Meta.Util.set_stage_input_region (screen, xregion);
        }
        
        public void move_window (Meta.Window? window, bool up) {
            if (window == null)
                return;
            
            if (window.is_on_all_workspaces ())
                return;
            var idx = screen.get_active_workspace ().index () + ((up)?-1:1);
            window.change_workspace_by_index (idx, false, 
                screen.get_display ().get_current_time ());
            
            screen.get_workspace_by_index (idx).activate_with_focus (window, 
                screen.get_display ().get_current_time ());
        }
        
        public new void begin_modal () {
            base.begin_modal (x_get_stage_window (Meta.Compositor.get_stage_for_screen (
                this.get_screen ())), {}, 0, this.get_screen ().get_display ().get_current_time ());
        }
        public new void end_modal () {
            base.end_modal (this.get_screen ().get_display ().get_current_time ());
        }
        
        public void window_switcher (Meta.Display display, Meta.Screen screen, 
            Meta.KeyBinding binding, bool backward) {
            if (screen.get_display ().get_tab_list (Meta.TabList.NORMAL, screen, 
                screen.get_active_workspace ()).length () == 0)
                return;
            
            this.begin_modal ();
            
            int w, h;
            this.get_screen ().get_size (out w, out h);
            this.winswitcher.list_windows (display, screen, binding, backward);
            
            this.winswitcher.x = w/2-winswitcher.width/2;
            this.winswitcher.y = h/2-winswitcher.height/2;
            this.winswitcher.grab_key_focus ();
            this.winswitcher.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, opacity:255);
        }
        
        public void workspace_switcher (Meta.Screen screen, bool up) {
            int w, h;
            this.get_screen ().get_size (out w, out h);
            
            wswitcher.x = w/2-wswitcher.width/2;
            wswitcher.y = h/2-wswitcher.height/2;
            wswitcher.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 100, opacity:255);
            wswitcher.workspace = move_workspaces (up);;
            
            this.begin_modal ();
            wswitcher.grab_key_focus ();
        }
        
        public int move_workspaces (bool up) {
            var i = screen.get_active_workspace_index ();
            if (up && i-1 >= 0) //move up
                i --;
            else if (!up && i+1 < screen.n_workspaces) //move down
                i ++;
            if (i != screen.get_active_workspace_index ()) {
                screen.get_workspace_by_index (i).
                    activate (screen.get_display ().get_current_time ());
            }
            return i;
        }
        
        public override void minimize (Meta.WindowActor actor) {
            this.minimize_completed (actor);
        }
        
        //stolen from original mutter plugin
        public override void maximize (Meta.WindowActor actor, int ex, int ey, int ew, int eh) {
            if (actor.meta_window.window_type == Meta.WindowType.NORMAL) {
                float x, y, width, height;
                actor.get_size (out width, out height);
                actor.get_position (out x, out y);
                
                float scale_x  = (float)ew  / width;
                float scale_y  = (float)eh / height;
                float anchor_x = (float)(x - ex) * width  / (ew - width);
                float anchor_y = (float)(y - ey) * height / (eh - height);
                
                actor.move_anchor_point (anchor_x, anchor_y);
                actor.animate (Clutter.AnimationMode.EASE_IN_SINE, 150, scale_x:scale_x, 
                    scale_y:scale_y).completed.connect ( () => {
                    actor.move_anchor_point_from_gravity (Clutter.Gravity.NORTH_WEST);
                    actor.animate (Clutter.AnimationMode.LINEAR, 1, scale_x:1.0f, 
                        scale_y:1.0f);//just scaling didnt want to work..
                    this.maximize_completed (actor);
                });
                
                return;
            }
            this.maximize_completed (actor);
        }
        
        public override void map (Meta.WindowActor actor) {
            actor.show ();
            switch (actor.meta_window.window_type) {
                case Meta.WindowType.NORMAL:
                    actor.scale_gravity = Clutter.Gravity.CENTER;
                    actor.rotation_center_x = {0, actor.height, 10};
                    actor.scale_x = 0.55f;
                    actor.scale_y = 0.55f;
                    actor.opacity = 0;
                    actor.rotation_angle_x = 40.0f;
                    actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 350, 
                        scale_x:1.0f, scale_y:1.0f, rotation_angle_x:0.0f, opacity:255)
                        .completed.connect ( () => {
                        this.map_completed (actor);
                    });
                    break;
                case Meta.WindowType.MENU:
                case Meta.WindowType.DROPDOWN_MENU:
                case Meta.WindowType.POPUP_MENU:
                case Meta.WindowType.MODAL_DIALOG:
                case Meta.WindowType.DIALOG:
                    actor.scale_gravity = Clutter.Gravity.NORTH;
                    actor.scale_x = 1.0f;
                    actor.scale_y = 0.0f;
                    actor.opacity = 0;
                    actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 150, 
                        scale_y:1.0f, opacity:255).completed.connect ( () => {
                        this.map_completed (actor);
                    });
                    break;
                default:
                    this.map_completed (actor);
                    break;
            }
        }
        public override void destroy (Meta.WindowActor actor) {
            switch (actor.meta_window.window_type) {
                case Meta.WindowType.NORMAL:
                    actor.scale_gravity = Clutter.Gravity.CENTER;
                    actor.rotation_center_x = {0, actor.height, 10};
                    actor.show ();
                    actor.animate (Clutter.AnimationMode.EASE_IN_QUAD, 250, 
                        scale_x:0.95f, scale_y:0.95f, opacity:0, rotation_angle_x:15.0f)
                        .completed.connect ( () => {
                        this.destroy_completed (actor);
                    });
                    break;
                case Meta.WindowType.MENU:
                case Meta.WindowType.DROPDOWN_MENU:
                case Meta.WindowType.POPUP_MENU:
                case Meta.WindowType.MODAL_DIALOG:
                case Meta.WindowType.DIALOG:
                    actor.scale_gravity = Clutter.Gravity.NORTH;
                    actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, 
                        scale_y:0.0f, opacity:0).completed.connect ( () => {
                        this.destroy_completed (actor);
                    });
                break;
                default:
                    this.destroy_completed (actor);
                    break;
            }
        }
        
        private GLib.List<Clutter.Actor> win;
        private GLib.List<Clutter.Actor> par; //class space for kill func
        private Clutter.Group in_group;
        private Clutter.Group out_group;
        
        public override void switch_workspace (int from, int to, Meta.MotionDirection direction) {
            unowned List<Clutter.Actor> windows = 
                Meta.Compositor.get_window_actors (this.get_screen ());
            //FIXME js/ui/windowManager.js line 430
            int w, h;
            this.get_screen ().get_size (out w, out h);
            
            var x2 = 0.0f; var y2 = 0.0f;
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
                    y2 = h;
            else if (direction == Meta.MotionDirection.RIGHT ||
                      direction == Meta.MotionDirection.UP_RIGHT ||
                      direction == Meta.MotionDirection.DOWN_RIGHT)
                    y2 = -h;
            
            var in_group  = new Clutter.Group ();
            var out_group = new Clutter.Group ();
            var group     = Meta.Compositor.get_window_group_for_screen (this.get_screen ());
            group.add_actor (in_group);
            group.add_actor (out_group);
            
            win = new List<Clutter.Actor> ();
            par = new List<Clutter.Actor> ();
            
            for (var i=0;i<windows.length ();i++) {
                var window = windows.nth_data (i);
                if (!(window as Meta.WindowActor).meta_window.showing_on_its_workspace ())
                    continue;
                
                win.append (window);
                par.append (window.get_parent ());
                if ((window as Meta.WindowActor).get_workspace () == from) {
                    window.reparent (out_group);
                } else if ((window as Meta.WindowActor).get_workspace () == to) {
                    window.reparent (in_group);
                    window.show_all ();
                }
            }
            in_group.set_position (-x2, -y2);
            in_group.raise_top ();
            
            out_group.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 300,
                x:x2, y:y2);
            in_group.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 300,
                x:0.0f, y:0.0f).completed.connect ( () => {
                end_switch_workspace ();
            });
        }
        public override void kill_window_effects (Meta.WindowActor actor){
            /*this.minimize_completed (actor);FIXME should call the things in anim.completed
            this.maximize_completed (actor);
            this.unmaximize_completed (actor);
            this.map_completed (actor);
            this.destroy_completed (actor);*/
        }
        private void end_switch_workspace () {
            if (win == null || par == null)
                return;
            
            for (var i=0;i<win.length ();i++) {
                var window = win.nth_data (i);
                if ((window as Meta.WindowActor).is_destroyed ())
                    continue;
                if (window.get_parent () == out_group) {
                    window.reparent (par.nth_data (i));
                    window.hide ();
                } else
                    window.reparent (par.nth_data (i));
            }
            win = null;
            par = null;
            
            if (in_group != null) {
                in_group.detach_animation ();
                in_group.destroy ();
            }
            if (out_group != null) {
                out_group.detach_animation ();
                out_group.destroy ();
            }
            
            this.switch_workspace_completed ();
        }
        public override void unmaximize (Meta.WindowActor actor, int x, int y, int w, int h) {
            this.unmaximize_completed (actor);
        }
        
        public override void kill_switch_workspace () {
            end_switch_workspace ();
        }
        public override bool xevent_filter (X.Event event) {
            return x_handle_event (event) != 0;
        }
        
        public override Meta.PluginInfo plugin_info () {
            return {"Gala", Gala.VERSION, "Tom Beckmann", "GPLv3", "A nice window manager"};
        }
        
    }
    
}