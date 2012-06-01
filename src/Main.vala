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
	public enum InputArea {
		NONE,
		FULLSCREEN,
		HOT_CORNER
	}
	
	public class Plugin : Meta.Plugin
	{
		WorkspaceSwitcher wswitcher;
		WindowSwitcher winswitcher;
		WorkspaceView workspace_view;
		Clutter.Actor elements;
		
		public Plugin ()
		{
			if (Settings.get_default().use_gnome_defaults)
				return;
			
			Prefs.override_preference_schema ("attach-modal-dialogs", SCHEMA);
			Prefs.override_preference_schema ("button-layout", SCHEMA);
			Prefs.override_preference_schema ("edge-tiling", SCHEMA);
			Prefs.override_preference_schema ("enable-animations", SCHEMA);
			Prefs.override_preference_schema ("theme", SCHEMA);
		}
		
		public override void start ()
		{
			elements = Compositor.get_stage_for_screen (screen);
			Compositor.get_window_group_for_screen (screen).reparent (elements);
			Compositor.get_overlay_group_for_screen (screen).reparent (elements);
			Compositor.get_stage_for_screen (screen).add_child (elements);
			
			screen.override_workspace_layout (ScreenCorner.TOPLEFT, false, 4, -1);
			
			int width, height;
			screen.get_size (out width, out height);
			
			workspace_view = new WorkspaceView (this);
			elements.add_child (workspace_view);
			workspace_view.visible = false;
			
			wswitcher = new WorkspaceSwitcher (this);
			wswitcher.workspaces = 4;
			elements.add_child (wswitcher);
			
			winswitcher = new WindowSwitcher (this);
			elements.add_child (winswitcher);
			
			KeyBinding.set_custom_handler ("panel-main-menu", () => {
				try {
					Process.spawn_command_line_async (
						Settings.get_default().panel_main_menu_action);
				} catch (Error e) { warning (e.message); }
			});
			
			KeyBinding.set_custom_handler ("toggle-recording", () => {
				try {
					Process.spawn_command_line_async (
						Settings.get_default().toggle_recording_action);
				} catch (Error e) { warning (e.message); }
			});
			
			KeyBinding.set_custom_handler ("show-desktop", () => {
				workspace_view.show ();
			});
			
			KeyBinding.set_custom_handler ("switch-windows", winswitcher.handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-windows-backward", winswitcher.handle_switch_windows);
			
			KeyBinding.set_custom_handler ("switch-to-workspace-up", () => {});
			KeyBinding.set_custom_handler ("switch-to-workspace-down", () => {});
			KeyBinding.set_custom_handler ("switch-to-workspace-left", wswitcher.handle_switch_to_workspace);
			KeyBinding.set_custom_handler ("switch-to-workspace-right", wswitcher.handle_switch_to_workspace);
			
			KeyBinding.set_custom_handler ("move-to-workspace-up", () => {});
			KeyBinding.set_custom_handler ("move-to-workspace-down", () => {});
			KeyBinding.set_custom_handler ("move-to-workspace-left",	(d, s, w) => move_window (w, true) );
			KeyBinding.set_custom_handler ("move-to-workspace-right",  (d, s, w) => move_window (w, false) );
			
			/*shadows*/
			ShadowFactory.get_default ().set_params ("normal", true, {20, -1, 0, 15, 153});
			
			/*hot corner*/
			var hot_corner = new Clutter.Rectangle ();
			hot_corner.x = width - 1;
			hot_corner.y = height - 1;
			hot_corner.width = 1;
			hot_corner.height = 1;
			hot_corner.reactive = true;
			
			hot_corner.enter_event.connect (() => {
				workspace_view.show ();
				return false;
			});
			
			Compositor.get_overlay_group_for_screen (screen).add_child (hot_corner);
			
			update_input_area ();
			Settings.get_default ().notify["enable-manager-corner"].connect (update_input_area);
		}
		
		void update_input_area ()
		{
			if (Settings.get_default ().enable_manager_corner)
				set_input_area (InputArea.HOT_CORNER);
			else
				set_input_area (InputArea.NONE);
		}
		
		/**
		 * returns a pixbuf for the application of this window or a default icon
		 **/
		public Gdk.Pixbuf get_icon_for_window (Window window, int size) {
			Gdk.Pixbuf image = null;
			
			var app = Bamf.Matcher.get_default ().get_application_for_xid ((uint32)window.get_xwindow ());
			if (app != null) {
				var desktop = new GLib.DesktopAppInfo.from_filename (app.get_desktop_file ());
				try {
					image = Gtk.IconTheme.get_default ().lookup_by_gicon (desktop.get_icon (), size, 0).load_icon ();
				} catch (Error e) { warning (e.message); }
			}
			
			if (image == null) {
				try {
					image = Gtk.IconTheme.get_default ().load_icon ("application-default-icon", size, 0);
				} catch (Error e) {
					warning (e.message);
				}
			}
			
			return image;
		}
		
		/**
		 * set the area where clutter can receive events
		 **/
		public void set_input_area (InputArea area)
		{
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
					Util.empty_stage_input_region (screen);
					return;
			}
			
			var xregion = X.Fixes.create_region (screen.get_display ().get_xdisplay (), {rect});
			Util.set_stage_input_region (screen, xregion);
		}
		
		void move_window (Window? window, bool up)
		{
			if (window == null || window.is_on_all_workspaces ())
				return;
			
			var idx = screen.get_active_workspace ().index () + ((up)?-1:1);
			window.change_workspace_by_index (idx, false, 
				screen.get_display ().get_current_time ());
			
			screen.get_workspace_by_index (idx).activate_with_focus (window, 
				screen.get_display ().get_current_time ());
		}
		
		public new void begin_modal ()
		{
			base.begin_modal (x_get_stage_window (Compositor.get_stage_for_screen (screen)), {}, 0, screen.get_display ().get_current_time ());
		}
		public new void end_modal ()
		{
			base.end_modal (get_screen ().get_display ().get_current_time ());
		}
		
		public int move_workspaces (bool left)
		{
			var i = screen.get_active_workspace_index ();
			
			if (left && i - 1 >= 0) //move left
				i --;
			else if (!left && i + 1 < screen.n_workspaces) //move down
				i ++;
			
			if (i != screen.get_active_workspace_index ()) {
				screen.get_workspace_by_index (i).
					activate (screen.get_display ().get_current_time ());
			}
			
			return i;
		}
		
		public override void minimize (WindowActor actor)
		{
			minimize_completed (actor);
		}
		
		//stolen from original mutter plugin
		public override void maximize (WindowActor actor, int ex, int ey, int ew, int eh)
		{
			if (actor.meta_window.window_type == WindowType.NORMAL) {
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
					maximize_completed (actor);
				});
				
				return;
			}
			
			maximize_completed (actor);
		}
		
		public override void map (WindowActor actor)
		{
			actor.show ();
			
			switch (actor.meta_window.window_type) {
				case WindowType.NORMAL:
					actor.scale_gravity = Clutter.Gravity.CENTER;
					actor.rotation_center_x = {0, actor.height, 10};
					actor.scale_x = 0.55f;
					actor.scale_y = 0.55f;
					actor.opacity = 0;
					actor.rotation_angle_x = 40.0f;
					actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 350, 
						scale_x:1.0f, scale_y:1.0f, rotation_angle_x:0.0f, opacity:255)
						.completed.connect ( () => {
						map_completed (actor);
					});
					break;
				case WindowType.MENU:
				case WindowType.DROPDOWN_MENU:
				case WindowType.POPUP_MENU:
				case WindowType.MODAL_DIALOG:
				case WindowType.DIALOG:
					actor.scale_gravity = Clutter.Gravity.NORTH;
					actor.scale_x = 1.0f;
					actor.scale_y = 0.0f;
					actor.opacity = 0;
					actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 150, 
						scale_y:1.0f, opacity:255).completed.connect ( () => {
						map_completed (actor);
					});
					break;
				default:
					map_completed (actor);
					break;
			}
		}
		
		public override void destroy (WindowActor actor)
		{
			switch (actor.meta_window.window_type) {
				case WindowType.NORMAL:
					actor.scale_gravity = Clutter.Gravity.CENTER;
					actor.rotation_center_x = {0, actor.height, 10};
					actor.show ();
					actor.animate (Clutter.AnimationMode.EASE_IN_QUAD, 250, 
						scale_x:0.95f, scale_y:0.95f, opacity:0, rotation_angle_x:15.0f)
						.completed.connect ( () => {
						destroy_completed (actor);
					});
					break;
				case WindowType.MENU:
				case WindowType.DROPDOWN_MENU:
				case WindowType.POPUP_MENU:
				case WindowType.MODAL_DIALOG:
				case WindowType.DIALOG:
					actor.scale_gravity = Clutter.Gravity.NORTH;
					actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, 
						scale_y:0.0f, opacity:0).completed.connect ( () => {
						destroy_completed (actor);
					});
				break;
				default:
					destroy_completed (actor);
					break;
			}
		}
		
		GLib.List<Clutter.Actor>? win;
		GLib.List<Clutter.Actor>? par; //class space for kill func
		Clutter.Group in_group;
		Clutter.Group out_group;
		
		public override void switch_workspace (int from, int to, MotionDirection direction)
		{
			unowned List<Clutter.Actor> windows = Compositor.get_window_actors (get_screen ());
			//FIXME js/ui/windowManager.js line 430
			int w, h;
			get_screen ().get_size (out w, out h);
			
			var x2 = 0.0f; var y2 = 0.0f;
			if (direction == MotionDirection.UP ||
				direction == MotionDirection.UP_LEFT ||
				direction == MotionDirection.UP_RIGHT)
				x2 = w;
			else if (direction == MotionDirection.DOWN ||
				direction == MotionDirection.DOWN_LEFT ||
				direction == MotionDirection.DOWN_RIGHT)
				x2 = -w;
			
			if (direction == MotionDirection.LEFT ||
				direction == MotionDirection.UP_LEFT ||
				direction == MotionDirection.DOWN_LEFT)
				x2 = w;
			else if (direction == MotionDirection.RIGHT ||
				direction == MotionDirection.UP_RIGHT ||
				direction == MotionDirection.DOWN_RIGHT)
				x2 = -w;
			
			var in_group  = new Clutter.Group ();
			var out_group = new Clutter.Group ();
			var group = Compositor.get_window_group_for_screen (get_screen ());
			group.add_actor (in_group);
			group.add_actor (out_group);
			
			win = new List<Clutter.Actor> ();
			par = new List<Clutter.Actor> ();
			
			for (var i=0;i<windows.length ();i++) {
				var window = windows.nth_data (i);
				if (!(window as WindowActor).meta_window.showing_on_its_workspace ())
					continue;
				
				win.append (window);
				par.append (window.get_parent ());
				if ((window as WindowActor).get_workspace () == from) {
					window.reparent (out_group);
				} else if ((window as WindowActor).get_workspace () == to) {
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
		
		public override void kill_window_effects (WindowActor actor)
		{
			/*FIXME should call the things in anim.completed
			minimize_completed (actor);
			maximize_completed (actor);
			unmaximize_completed (actor);
			map_completed (actor);
			destroy_completed (actor);
			*/
		}
		
		void end_switch_workspace ()
		{
			if (win == null || par == null)
				return;
			
			for (var i=0;i<win.length ();i++) {
				var window = win.nth_data (i);
				if ((window as WindowActor).is_destroyed ())
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
			
			switch_workspace_completed ();
		}
		
		public override void unmaximize (Meta.WindowActor actor, int x, int y, int w, int h)
		{
			unmaximize_completed (actor);
		}
		
		public override void kill_switch_workspace ()
		{
			end_switch_workspace ();
		}
		
		public override bool xevent_filter (X.Event event)
		{
			return x_handle_event (event) != 0;
		}
		
		public override PluginInfo plugin_info ()
		{
			return {"Gala", Gala.VERSION, "Tom Beckmann", "GPLv3", "A nice window manager"};
		}
		
	}
	
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
	
	[CCode (cname="clutter_x11_handle_event")]
	public extern int x_handle_event (X.Event xevent);
	[CCode (cname="clutter_x11_get_stage_window")]
	public extern X.Window x_get_stage_window (Clutter.Actor stage);
	
	int main (string [] args) {
		
		unowned OptionContext ctx = Meta.get_option_context ();
		ctx.add_main_entries (Gala.OPTIONS, null);
		try {
		    ctx.parse (ref args);
		} catch (Error e) {
		    stderr.printf ("Error initializing: %s\n", e.message);
		    Meta.exit (Meta.ExitCode.ERROR);
		}
		
		Meta.Plugin.type_register (new Gala.Plugin ().get_type ());
		
		/**
		 * Prevent Meta.init () from causing gtk to load gail and at-bridge
		 * Taken from Gnome-Shell main.c
		 */
		GLib.Environment.set_variable ("NO_GAIL", "1", true);
		GLib.Environment.set_variable ("NO_AT_BRIDGE", "1", true);
		Meta.init ();
		GLib.Environment.unset_variable ("NO_GAIL");
		GLib.Environment.unset_variable ("NO_AT_BRIDGE");
		
		return Meta.run ();
	}
}
