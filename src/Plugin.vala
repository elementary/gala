//  
//  Copyright (C) 2012 Tom Beckmann, Rico Tzschichholz
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
// 

using Meta;

namespace Gala
{
	public enum ActionType
	{
		NONE = 0,
		SHOW_WORKSPACE_VIEW,
		MAXIMIZE_CURRENT,
		MINIMIZE_CURRENT,
		OPEN_LAUNCHER,
		CUSTOM_COMMAND,
		WINDOW_OVERVIEW,
		WINDOW_OVERVIEW_ALL
	}
	
	public enum InputArea {
		NONE,
		FULLSCREEN,
		HOT_CORNER
	}
	
	public class Plugin : Meta.Plugin
	{
		PluginInfo info;
		
		WindowSwitcher winswitcher;
		WorkspaceView workspace_view;
		Zooming zooming;
		WindowOverview window_overview;
		
#if HAS_MUTTER38
		// FIXME we need a proper-sized background for every monitor
		public BackgroundActor wallpaper { get; private set; }
#endif
		
		Window? moving; //place for the window that is being moved over
		
		int modal_count = 0; //count of modal modes overlaying each other
		
		Gee.HashSet<Meta.WindowActor> minimizing = new Gee.HashSet<Meta.WindowActor> ();
		Gee.HashSet<Meta.WindowActor> maximizing = new Gee.HashSet<Meta.WindowActor> ();
		Gee.HashSet<Meta.WindowActor> unmaximizing = new Gee.HashSet<Meta.WindowActor> ();
		Gee.HashSet<Meta.WindowActor> mapping = new Gee.HashSet<Meta.WindowActor> ();
		Gee.HashSet<Meta.WindowActor> destroying = new Gee.HashSet<Meta.WindowActor> ();
		
		public Plugin ()
		{
			info = PluginInfo () {name = "Gala", version = Config.VERSION, author = "Gala Developers",
				license = "GPLv3", description = "A nice elementary window manager"};
			
			Prefs.set_ignore_request_hide_titlebar (true);
			Prefs.override_preference_schema ("dynamic-workspaces", Config.SCHEMA + ".behavior");
			Prefs.override_preference_schema ("attach-modal-dialogs", Config.SCHEMA + ".appearance");
			Prefs.override_preference_schema ("button-layout", Config.SCHEMA + ".appearance");
			Prefs.override_preference_schema ("edge-tiling", Config.SCHEMA + ".behavior");
			Prefs.override_preference_schema ("enable-animations", Config.SCHEMA + ".animations");
		}
		
		public override void start ()
		{
#if HAS_MUTTER38
			Util.later_add (LaterType.BEFORE_REDRAW, show_stage);
		}
		
		bool show_stage ()
		{
#endif
			var screen = get_screen ();
			
			DBus.init (this);
			
			var stage = Compositor.get_stage_for_screen (screen) as Clutter.Stage;
			
			string color = new Settings ("org.gnome.desktop.background").get_string ("primary-color");
			stage.background_color = Clutter.Color.from_string (color);
			stage.no_clear_hint = true;
			
			if (Prefs.get_dynamic_workspaces ())
				screen.override_workspace_layout (ScreenCorner.TOPLEFT, false, 1, -1);
			
			workspace_view = new WorkspaceView (this);
			workspace_view.visible = false;
			
			winswitcher = new WindowSwitcher (this);
			
			zooming = new Zooming (this);
			window_overview = new WindowOverview (this);
			
			stage.add_child (workspace_view);
			stage.add_child (winswitcher);
			stage.add_child (window_overview);
			
#if HAS_MUTTER38
			// FIXME create a background for every monitor and keep them updated and properly sized
			wallpaper = new BackgroundActor ();
#endif
			
			/*keybindings*/
			
			screen.get_display ().add_keybinding ("expose-windows", KeybindingSettings.get_default ().schema, 0, () => {
				window_overview.open (true);
			});
			screen.get_display ().add_keybinding ("expose-all-windows", KeybindingSettings.get_default ().schema, 0, () => {
				window_overview.open (true, true);
			});
			screen.get_display ().add_keybinding ("switch-to-workspace-first", KeybindingSettings.get_default ().schema, 0, () => {
				screen.get_workspace_by_index (0).activate (screen.get_display ().get_current_time ());
			});
			screen.get_display ().add_keybinding ("switch-to-workspace-last", KeybindingSettings.get_default ().schema, 0, () => {
				screen.get_workspace_by_index (screen.n_workspaces - 1).activate (screen.get_display ().get_current_time ());
			});
			screen.get_display ().add_keybinding ("move-to-workspace-first", KeybindingSettings.get_default ().schema, 0, () => {
				var workspace = screen.get_workspace_by_index (0);
				var window = screen.get_display ().get_focus_window ();
				window.change_workspace (workspace);
				workspace.activate_with_focus (window, screen.get_display ().get_current_time ());
			});
			screen.get_display ().add_keybinding ("move-to-workspace-last", KeybindingSettings.get_default ().schema, 0, () => {
				var workspace = screen.get_workspace_by_index (screen.get_n_workspaces () - 1);
				var window = screen.get_display ().get_focus_window ();
				window.change_workspace (workspace);
				workspace.activate_with_focus (window, screen.get_display ().get_current_time ());
			});
			screen.get_display ().add_keybinding ("zoom-in", KeybindingSettings.get_default ().schema, 0, () => {
				zooming.zoom_in ();
			});
			screen.get_display ().add_keybinding ("zoom-out", KeybindingSettings.get_default ().schema, 0, () => {
				zooming.zoom_out ();
			});
			
			screen.get_display ().overlay_key.connect (() => {
				try {
					Process.spawn_command_line_async (
						BehaviorSettings.get_default ().overlay_action);
				} catch (Error e) { warning (e.message); }
			});
			
			KeyBinding.set_custom_handler ("panel-main-menu", () => {
				try {
					Process.spawn_command_line_async (
						BehaviorSettings.get_default ().panel_main_menu_action);
				} catch (Error e) { warning (e.message); }
			});
			
			KeyBinding.set_custom_handler ("toggle-recording", () => {
				try {
					Process.spawn_command_line_async (
						BehaviorSettings.get_default ().toggle_recording_action);
				} catch (Error e) { warning (e.message); }
			});
			
			KeyBinding.set_custom_handler ("show-desktop", () => {
				workspace_view.show (true);
			});
			
			KeyBinding.set_custom_handler ("switch-windows", winswitcher.handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-windows-backward", winswitcher.handle_switch_windows);
			
			KeyBinding.set_custom_handler ("switch-to-workspace-up", () => {});
			KeyBinding.set_custom_handler ("switch-to-workspace-down", () => {});
			KeyBinding.set_custom_handler ("switch-to-workspace-left", workspace_view.handle_switch_to_workspace);
			KeyBinding.set_custom_handler ("switch-to-workspace-right", workspace_view.handle_switch_to_workspace);
			
			KeyBinding.set_custom_handler ("move-to-workspace-up", () => {});
			KeyBinding.set_custom_handler ("move-to-workspace-down", () => {});
			KeyBinding.set_custom_handler ("move-to-workspace-left",  (d, s, w) => move_window (w, MotionDirection.LEFT) );
			KeyBinding.set_custom_handler ("move-to-workspace-right", (d, s, w) => move_window (w, MotionDirection.RIGHT) );
			
			KeyBinding.set_custom_handler ("switch-group", () => {});
			KeyBinding.set_custom_handler ("switch-group-backward", () => {});
			
			/*shadows*/
			Utils.reload_shadow ();
			ShadowSettings.get_default ().notify.connect (Utils.reload_shadow);
			
			/*hot corner, getting enum values from GraniteServicesSettings did not work, so we use GSettings directly*/
			configure_hotcorners ();
			screen.monitors_changed.connect (configure_hotcorners);
			
			BehaviorSettings.get_default ().schema.changed.connect ((key) => update_input_area ());

#if HAS_MUTTER38
			stage.show ();
			
			return false;
#endif
		}
		
		void configure_hotcorners ()
		{
			var geometry = get_screen ().get_monitor_geometry (get_screen ().get_primary_monitor ());
			
			add_hotcorner (geometry.x, geometry.y, "hotcorner-topleft");
			add_hotcorner (geometry.x + geometry.width - 1, geometry.y, "hotcorner-topright");
			add_hotcorner (geometry.x, geometry.y + geometry.height - 1, "hotcorner-bottomleft");
			add_hotcorner (geometry.x + geometry.width - 1, geometry.y + geometry.height - 1, "hotcorner-bottomright");
			
			update_input_area ();
		}
		
		void add_hotcorner (float x, float y, string key)
		{
			Clutter.Actor hot_corner;
			var stage = Compositor.get_stage_for_screen (get_screen ());
			
			// if the hot corner already exists, just reposition it, create it otherwise
			if ((hot_corner = stage.find_child_by_name (key)) == null) {
				hot_corner = new Clutter.Actor ();
				hot_corner.width = 1;
				hot_corner.height = 1;
				hot_corner.opacity = 0;
				hot_corner.reactive = true;
				hot_corner.name = key;
				
				stage.add_child (hot_corner);
				
				hot_corner.enter_event.connect (() => {
					perform_action ((ActionType)BehaviorSettings.get_default ().schema.get_enum (key));
					return false;
				});
			}
			
			hot_corner.x = x;
			hot_corner.y = y;
		}
		
		public void update_input_area ()
		{
			var schema = BehaviorSettings.get_default ().schema;
			
			if (schema.get_enum ("hotcorner-topleft") != ActionType.NONE ||
				schema.get_enum ("hotcorner-topright") != ActionType.NONE ||
				schema.get_enum ("hotcorner-bottomleft") != ActionType.NONE ||
				schema.get_enum ("hotcorner-bottomright") != ActionType.NONE)
				Utils.set_input_area (get_screen (), InputArea.HOT_CORNER);
			else
				Utils.set_input_area (get_screen (), InputArea.NONE);
		}
		
		public void move_window (Window? window, MotionDirection direction)
		{
			if (window == null)
				return;
			
			var screen = get_screen ();
			var display = screen.get_display ();
			
			var active = screen.get_active_workspace ();
			var next = active.get_neighbor (direction);
			
			//dont allow empty workspaces to be created by moving, if we have dynamic workspaces
			if (Prefs.get_dynamic_workspaces () && active.n_windows == 1 && next.index () ==  screen.n_workspaces - 1)
				return;
			
			moving = window;
			
			if (!window.is_on_all_workspaces ())
				window.change_workspace (next);
			
			next.activate_with_focus (window, display.get_current_time ());
		}
		
		public new void begin_modal ()
		{
			modal_count ++;
			if (modal_count > 1)
				return;
			
			var screen = get_screen ();
			var display = screen.get_display ();
			
			base.begin_modal (x_get_stage_window (Compositor.get_stage_for_screen (screen)), {}, 0, display.get_current_time ());
		}
		
		public new void end_modal ()
		{
			modal_count --;
			if (modal_count > 0)
				return;
			
			base.end_modal (get_screen ().get_display ().get_current_time ());
		}
		
		public void get_current_cursor_position (out int x, out int y)
		{
			Gdk.Display.get_default ().get_device_manager ().get_client_pointer ().get_position (null, 
				out x, out y);
		}
		
		public void dim_window (Window window, bool dim)
		{
			/*FIXME we need a super awesome blureffect here, the one from clutter is just... bah!
			var win = window.get_compositor_private () as WindowActor;
			if (dim) {
				if (win.has_effects ())
					return;
				win.add_effect_with_name ("darken", new Clutter.BlurEffect ());
			} else
				win.clear_effects ();*/
		}
		
		public void perform_action (ActionType type)
		{
			var screen = get_screen ();
			var display = screen.get_display ();
			var current = display.get_focus_window ();
			
			switch (type) {
				case ActionType.SHOW_WORKSPACE_VIEW:
					workspace_view.show ();
					break;
				case ActionType.MAXIMIZE_CURRENT:
					if (current == null || current.window_type != WindowType.NORMAL)
						break;
					
					if (current.get_maximized () == (MaximizeFlags.HORIZONTAL | MaximizeFlags.VERTICAL))
						current.unmaximize (MaximizeFlags.HORIZONTAL | MaximizeFlags.VERTICAL);
					else
						current.maximize (MaximizeFlags.HORIZONTAL | MaximizeFlags.VERTICAL);
					break;
				case ActionType.MINIMIZE_CURRENT:
					if (current != null && current.window_type == WindowType.NORMAL)
						current.minimize ();
					break;
				case ActionType.OPEN_LAUNCHER:
					try {
						Process.spawn_command_line_async (BehaviorSettings.get_default ().panel_main_menu_action);
					} catch (Error e) {
						warning (e.message);
					}
					break;
				case ActionType.CUSTOM_COMMAND:
					try {
						Process.spawn_command_line_async (BehaviorSettings.get_default ().hotcorner_custom_command);
					} catch (Error e) {
						warning (e.message);
					}
					break;
				case ActionType.WINDOW_OVERVIEW:
					window_overview.open (true);
					break;
				case ActionType.WINDOW_OVERVIEW_ALL:
					window_overview.open (true, true);
					break;
				default:
					warning ("Trying to run unknown action");
					break;
			}
		}
		
		/*
		 * effects
		 */
		
		public override void minimize (WindowActor actor)
		{
			if (!AnimationSettings.get_default ().enable_animations || 
				AnimationSettings.get_default ().minimize_duration == 0 || 
				actor.get_meta_window ().window_type != WindowType.NORMAL) {
				minimize_completed (actor);
				return;
			}
			
			kill_window_effects (actor);
			minimizing.add (actor);
			
			int width, height;
			get_screen ().get_size (out width, out height);
			
			Rectangle icon = {};
			//FIXME don't use the icon geometry, since it seems broken right now
			if (false && actor.get_meta_window ().get_icon_geometry (out icon)) {
				
				float scale_x  = (float)icon.width  / actor.width;
				float scale_y  = (float)icon.height / actor.height;
				float anchor_x = (float)(actor.x - icon.x) * actor.width  / (icon.width  - actor.width);
				float anchor_y = (float)(actor.y - icon.y) * actor.height / (icon.height - actor.height);
				
				actor.move_anchor_point (anchor_x, anchor_y);
				actor.animate (Clutter.AnimationMode.EASE_IN_EXPO, AnimationSettings.get_default ().minimize_duration, 
					scale_x:scale_x, scale_y:scale_y,opacity:0)
					.completed.connect (() => {
					actor.anchor_gravity = Clutter.Gravity.NORTH_WEST;
					minimize_completed (actor);
					minimizing.remove (actor);
				});
				
			} else {
				actor.scale_center_x = width / 2.0f - actor.x;
				actor.scale_center_y = height - actor.y;
				actor.animate (Clutter.AnimationMode.EASE_IN_EXPO, AnimationSettings.get_default ().minimize_duration, 
					scale_x : 0.0f, scale_y : 0.0f, opacity : 0)
					.completed.connect (() => {
					actor.scale_gravity = Clutter.Gravity.NORTH_WEST;
					minimize_completed (actor);
					minimizing.remove (actor);
				});
			}
		}
		
		//stolen from original mutter plugin
		public override void maximize (WindowActor actor, int ex, int ey, int ew, int eh)
		{
			float x, y, width, height;
			actor.get_size (out width, out height);
			actor.get_position (out x, out y);
			
			if (!AnimationSettings.get_default ().enable_animations || 
				AnimationSettings.get_default ().snap_duration == 0 || 
				(x == ex && y == ey && ew == width && eh == height)) {
				maximize_completed (actor);
				return;
			}
			
			if (actor.get_meta_window ().window_type == WindowType.NORMAL) {
				maximizing.add (actor);
				
				float scale_x  = (float)ew  / width;
				float scale_y  = (float)eh / height;
				float anchor_x = (float)(x - ex) * width  / (ew - width);
				float anchor_y = (float)(y - ey) * height / (eh - height);
				
				//reset the actor's anchors
				actor.scale_gravity = actor.anchor_gravity = Clutter.Gravity.NORTH_WEST;
				
				actor.move_anchor_point (anchor_x, anchor_y);
				actor.animate (Clutter.AnimationMode.EASE_IN_OUT_SINE, AnimationSettings.get_default ().snap_duration, 
					scale_x:scale_x, scale_y:scale_y).get_timeline ().completed.connect ( () => {
					
					actor.anchor_gravity = Clutter.Gravity.NORTH_WEST;
					actor.set_scale (1.0, 1.0);
					
					maximizing.remove (actor);
					maximize_completed (actor);
				});
				
				return;
			}
			
			maximize_completed (actor);
		}
		
		public override void map (WindowActor actor)
		{
			if (!AnimationSettings.get_default ().enable_animations) {
				actor.show ();
				map_completed (actor);
				return;
			}
			
			var window = actor.get_meta_window ();
			
			actor.detach_animation ();
			actor.show ();
			
			switch (window.window_type) {
				case WindowType.NORMAL:
					if (AnimationSettings.get_default ().open_duration == 0) {
						map_completed (actor);
						return;
					}
					
					mapping.add (actor);
					
					actor.scale_gravity = Clutter.Gravity.SOUTH;
					actor.scale_x = 0.01f;
					actor.scale_y = 0.1f;
					actor.opacity = 0;
					actor.animate (Clutter.AnimationMode.EASE_OUT_EXPO, AnimationSettings.get_default ().open_duration, 
						scale_x:1.0f, scale_y:1.0f, opacity:255)
						.completed.connect ( () => {
						
						mapping.remove (actor);
						map_completed (actor);
					});
					break;
				case WindowType.MENU:
				case WindowType.DROPDOWN_MENU:
				case WindowType.POPUP_MENU:
					if (AnimationSettings.get_default ().menu_duration == 0) {
						map_completed (actor);
						return;
					}
					
					mapping.add (actor);
					
					actor.scale_gravity = Clutter.Gravity.CENTER;
					actor.rotation_center_x = {0, 0, 10};
					actor.scale_x = 0.9f;
					actor.scale_y = 0.9f;
					actor.opacity = 0;
					actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, AnimationSettings.get_default ().menu_duration, 
						scale_x:1.0f, scale_y:1.0f, opacity:255)
						.completed.connect ( () => {
						
						mapping.remove (actor);
						map_completed (actor);
					});
					break;
				case WindowType.MODAL_DIALOG:
				case WindowType.DIALOG:
					
					mapping.add (actor);
					
					actor.scale_gravity = Clutter.Gravity.NORTH;
					actor.scale_y = 0.0f;
					actor.opacity = 0;
					
					actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, 
						scale_y:1.0f, opacity:255).completed.connect ( () => {
						
						mapping.remove (actor);
						map_completed (actor);
					});
					
					if (AppearanceSettings.get_default ().dim_parents &&
						window.window_type == WindowType.MODAL_DIALOG && 
						window.is_attached_dialog ())
						dim_window (window.find_root_ancestor (), true);
					
					break;
				default:
					map_completed (actor);
					break;
			}
		}
		
		public override void destroy (WindowActor actor)
		{
			if (!AnimationSettings.get_default ().enable_animations) {
				destroy_completed (actor);
				return;
			}
			
			var window = actor.get_meta_window ();
			
			actor.detach_animation ();
			
			switch (window.window_type) {
				case WindowType.NORMAL:
					if (AnimationSettings.get_default ().close_duration == 0) {
						destroy_completed (actor);
						return;
					}
					
					destroying.add (actor);
					
					actor.scale_gravity = Clutter.Gravity.CENTER;
					actor.show ();
					actor.animate (Clutter.AnimationMode.LINEAR, AnimationSettings.get_default ().close_duration, 
						scale_x:0.8f, scale_y:0.8f, opacity:0)
						.completed.connect ( () => {
						
						destroying.remove (actor);
						destroy_completed (actor);
					});
					break;
				case WindowType.MODAL_DIALOG:
				case WindowType.DIALOG:
					destroying.add (actor);
					
					actor.scale_gravity = Clutter.Gravity.NORTH;
					actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, 
						scale_y:0.0f, opacity:0).completed.connect ( () => {
						
						destroying.remove (actor);
						destroy_completed (actor);
					});
					
					dim_window (window.find_root_ancestor (), false);
					
					break;
				case WindowType.MENU:
				case WindowType.DROPDOWN_MENU:
				case WindowType.POPUP_MENU:
					if (AnimationSettings.get_default ().menu_duration == 0) {
						destroy_completed (actor);
						return;
					}
					
					destroying.add (actor);
					
					actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, AnimationSettings.get_default ().menu_duration, 
						scale_x:0.8f, scale_y:0.8f, opacity:0)
						.completed.connect ( () => {
						
						destroying.remove (actor);
						destroy_completed (actor);
					});
					break;
				default:
					destroy_completed (actor);
					break;
			}
		}
		
		public override void unmaximize (Meta.WindowActor actor, int ex, int ey, int ew, int eh)
		{
			if (!AnimationSettings.get_default ().enable_animations || AnimationSettings.get_default ().snap_duration == 0) {
				unmaximize_completed (actor);
				return;
			}
			
			if (actor.get_meta_window ().window_type == WindowType.NORMAL) {
				unmaximizing.add (actor);
				
				float x, y, width, height;
				actor.get_size (out width, out height);
				actor.get_position (out x, out y);
				
				float scale_x  = (float)ew  / width;
				float scale_y  = (float)eh / height;
				float anchor_x = (float)(x - ex) * width  / (ew - width);
				float anchor_y = (float)(y - ey) * height / (eh - height);
				
				actor.move_anchor_point (anchor_x, anchor_y);
				actor.animate (Clutter.AnimationMode.EASE_IN_OUT_SINE, AnimationSettings.get_default ().snap_duration, 
					scale_x:scale_x, scale_y:scale_y).completed.connect ( () => {
					actor.move_anchor_point_from_gravity (Clutter.Gravity.NORTH_WEST);
					actor.animate (Clutter.AnimationMode.LINEAR, 1, scale_x:1.0f, 
						scale_y:1.0f);//just scaling didnt want to work..
					
					unmaximizing.remove (actor);
					unmaximize_completed (actor);
				});
				
				return;
			}
			
			unmaximize_completed (actor);
		}
		
		// Cancel attached animation of an actor and reset it
		bool end_animation (ref Gee.HashSet<Meta.WindowActor> list, WindowActor actor)
		{
			if (!list.contains (actor))
				return false;
			
			if (actor.is_destroyed ()) {
				list.remove (actor);
				return false;
			}
			
			actor.detach_animation ();
			actor.opacity = 255;
			actor.scale_x = 1.0f;
			actor.scale_y = 1.0f;
			actor.rotation_angle_x = 0.0f;
			actor.anchor_gravity = Clutter.Gravity.NORTH_WEST;
			actor.scale_gravity = Clutter.Gravity.NORTH_WEST;
			
			list.remove (actor);
			return true;
		}
		
		public override void kill_window_effects (WindowActor actor)
		{
			if (end_animation (ref mapping, actor))
				map_completed (actor);
			if (end_animation (ref minimizing, actor))
				minimize_completed (actor);
			if (end_animation (ref maximizing, actor))
				maximize_completed (actor);
			if (end_animation (ref unmaximizing, actor))
				unmaximize_completed (actor);
			if (end_animation (ref destroying, actor))
				destroy_completed (actor);
		}
		
		/*workspace switcher*/
		List<WindowActor>? win;
		List<Clutter.Actor>? par; //class space for kill func
		List<Clutter.Clone>? clones;
		Clutter.Actor? in_group;
		Clutter.Actor? out_group;
		Clutter.Actor? moving_window_container;
		
		void watch_window (Meta.Workspace workspace, Meta.Window window)
		{
			if (clones == null) {
				critical ("watch_window called on '%s' while not switching workspaces", window.get_title ());
				return;
			}

			warning ("Dock window '%s' closed while switching workspaces", window.get_title ());
			
			// finding the correct window here is not so easy
			// and for those default 400ms we can live with
			// some windows disappearing which in fact should never
			// happen unless a dock crashes
			foreach (var clone in clones) {
				clone.destroy ();
			}
			clones = null;
		}
		
		public override void switch_workspace (int from, int to, MotionDirection direction)
		{
			if (!AnimationSettings.get_default ().enable_animations || AnimationSettings.get_default ().workspace_switch_duration == 0) {
				switch_workspace_completed ();
				return;
			}
			
			var screen = get_screen ();
			
			unowned List<WindowActor> windows = Compositor.get_window_actors (screen);
			float w, h;
			screen.get_size (out w, out h);
			
			var x2 = 0.0f; var y2 = 0.0f;
			if (direction == MotionDirection.LEFT)
				x2 = w;
			else if (direction == MotionDirection.RIGHT)
				x2 = -w;
			else
				return;
			
			var group = Compositor.get_window_group_for_screen (screen);
#if !HAS_MUTTER38
			var wallpaper = Compositor.get_background_actor_for_screen (screen);
#endif
			
			in_group  = new Clutter.Actor ();
			out_group = new Clutter.Actor ();
			win = new List<WindowActor> ();
			par = new List<Clutter.Actor> ();
			clones = new List<Clutter.Clone> ();
			
			var wallpaper_clone = new Clutter.Clone (wallpaper);
			wallpaper_clone.x = (x2 < 0 ? w : -w);
			
			clones.append (wallpaper_clone);
			
			group.add_child (wallpaper_clone);
			group.add_child (in_group);
			group.add_child (out_group);
			
			WindowActor moving_actor = null;
			if (moving != null) {
				moving_actor = moving.get_compositor_private () as WindowActor;
				
				win.append (moving_actor);
				par.append (moving_actor.get_parent ());
				
				// for some reason the actor alone won't stay where it should, only in a container
				moving_window_container = new Clutter.Actor ();
				clutter_actor_reparent (moving_actor, moving_window_container);
				group.add_child (moving_window_container);
			}
			
			var to_has_fullscreened = false;
			var from_has_fullscreened = false;
			var docks = new List<WindowActor> ();
			
			foreach (var window in windows) {
				var meta_window = window.get_meta_window ();
				
				if (!meta_window.showing_on_its_workspace () || 
					moving != null && window == moving_actor)
					continue;
				
				if (window.get_workspace () == from) {
					win.append (window);
					par.append (window.get_parent ());
					clutter_actor_reparent (window, out_group);
					if (meta_window.fullscreen)
						from_has_fullscreened = true;
				} else if (window.get_workspace () == to) {
					win.append (window);
					par.append (window.get_parent ());
					clutter_actor_reparent (window, in_group);
					if (meta_window.fullscreen)
						to_has_fullscreened = true;
				} else if (meta_window.window_type == WindowType.DOCK) {
					docks.append (window);
				}
			}
			
			// make sure we don't add docks when there are fullscreened
			// windows on one of the groups. Simply raising seems not to 
			// work, mutter probably reverts the order internally to match
			// the display stack
			foreach (var window in docks) {
				win.append (window);
				par.append (window.get_parent ());
				
				var clone = new Clutter.Clone (window);
				clone.x = window.x;
				clone.y = window.y;
				
				clones.append (clone);
				if (!to_has_fullscreened)
					in_group.add_child (clone);
				if (!from_has_fullscreened)
					clutter_actor_reparent (window, out_group);
			}
			
			// monitor the workspaces to see whether a window was removed
			// in which case we need to stop the clones from drawing
			// we monitor every workspace here because finding the ones a
			// particular dock belongs to did not seem reliable enough
			foreach (var workspace in screen.get_workspaces ()) {
				workspace.window_removed.connect (watch_window);
			}
			
			in_group.set_position (-x2, -y2);
			group.set_child_above_sibling (in_group, null);
			if (moving_window_container != null)
				group.set_child_above_sibling (moving_window_container, null);
			
			in_group.clip_to_allocation = out_group.clip_to_allocation = true;
			in_group.width = out_group.width = w;
			in_group.height = out_group.height = h;
			
			var animation_duration = AnimationSettings.get_default ().workspace_switch_duration;
			var animation_mode = Clutter.AnimationMode.EASE_OUT_CUBIC;
			
			out_group.animate (animation_mode, animation_duration, x : x2, y : y2);
			in_group.animate (animation_mode, animation_duration, x : 0.0f, y : 0.0f).completed.connect (() => {
				end_switch_workspace ();
			});
			wallpaper.animate (animation_mode, animation_duration, x : (x2 < 0 ? -w : w));
			wallpaper_clone.animate (animation_mode, animation_duration, x : 0.0f);
		}
		
		void end_switch_workspace ()
		{
			if (win == null || par == null)
				return;
			
			var screen = get_screen ();
			var display = screen.get_display ();
			
			for (var i=0;i<win.length ();i++) {
				var window = win.nth_data (i);
				if (window == null || window.is_destroyed ())
					continue;
				
				if (window.get_parent () == out_group) {
					clutter_actor_reparent (window, par.nth_data (i));
					window.hide ();
				} else
					clutter_actor_reparent (window, par.nth_data (i));
			}
			
			foreach (var workspace in screen.get_workspaces ()) {
				workspace.window_removed.disconnect (watch_window);
			}
			
			if (clones != null) {
				foreach (var clone in clones) {
					clone.destroy ();
				}
				clones = null;
			}
			
			win = null;
			par = null;
			
			if (in_group != null)
				in_group.destroy ();
			in_group = null;
			if (out_group != null)
				out_group.destroy ();
			out_group = null;
			if (moving_window_container != null)
				moving_window_container.destroy ();
			moving_window_container = null;
			
#if !HAS_MUTTER38
			var wallpaper = Compositor.get_background_actor_for_screen (screen);
#endif
			wallpaper.detach_animation ();
			wallpaper.x = 0.0f;
			
			switch_workspace_completed ();
			
			moving = null;
		}
		
		public override void kill_switch_workspace ()
		{
			end_switch_workspace ();
		}
		
		public override bool xevent_filter (X.Event event)
		{
			return x_handle_event (event) != 0;
		}
		
		public override unowned PluginInfo? plugin_info ()
		{
			return info;
		}
		
		static void clutter_actor_reparent (Clutter.Actor actor, Clutter.Actor new_parent)
		{
			if (actor == new_parent)
				return;
			
			actor.ref ();
			actor.get_parent ().remove_child (actor);
			new_parent.add_child (actor);
			actor.unref ();
		}
	}
	
	[CCode (cname="clutter_x11_handle_event")]
	public extern int x_handle_event (X.Event xevent);
	[CCode (cname="clutter_x11_get_stage_window")]
	public extern X.Window x_get_stage_window (Clutter.Actor stage);
}
