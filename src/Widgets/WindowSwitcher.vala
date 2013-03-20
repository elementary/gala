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

using Clutter;
using Granite.Drawing;

namespace Gala
{
	public class WindowSwitcher : Clutter.Actor
	{
		Gala.Plugin plugin;
		
		Gee.ArrayList<Clutter.Clone> window_clones = new Gee.ArrayList<Clutter.Clone> ();
		
		Meta.Window? current_window;
		
		Meta.WindowActor? dock_window;
		Actor dock;
		CairoTexture dock_background;
		Plank.Drawing.DockSurface? dock_surface;
		Plank.Drawing.DockTheme dock_theme;
		Plank.DockPreferences dock_settings;
		BindConstraint y_constraint;
		BindConstraint h_constraint;

		bool closing = false;
		
		//estimated value, if possible
		float dock_width = 0.0f;
		
		public WindowSwitcher (Gala.Plugin _plugin)
		{
			plugin = _plugin;
			
			//pull drawing methods from libplank
			dock_settings = new Plank.DockPreferences.with_filename (Environment.get_user_config_dir () + "/plank/dock1/settings");
			dock_settings.changed.connect (update_dock);
			
			dock_theme = new Plank.Drawing.DockTheme (dock_settings.Theme);
			dock_theme.load ("dock");
			dock_theme.changed.connect (update_dock);
			
			dock = new Actor ();
			dock.layout_manager = new BoxLayout ();
			dock.anchor_gravity = Clutter.Gravity.CENTER;
			
			dock_background = new CairoTexture (100, dock_settings.IconSize);
			dock_background.anchor_gravity = Clutter.Gravity.CENTER;
			dock_background.auto_resize = true;
			dock_background.draw.connect (draw_dock_background);
			
			y_constraint = new BindConstraint (dock, BindCoordinate.Y, 0);
			h_constraint = new BindConstraint (dock, BindCoordinate.HEIGHT, 0);
			
			dock_background.add_constraint (new BindConstraint (dock, BindCoordinate.X, 0));
			dock_background.add_constraint (y_constraint);
			dock_background.add_constraint (new BindConstraint (dock, BindCoordinate.WIDTH, 0));
			dock_background.add_constraint (h_constraint);
			
			add_child (dock_background);
			add_child (dock);
			
			update_dock ();
			
			visible = false;
		}
		
		//set the values which don't get set every time and need to be updated when the theme changes
		void update_dock ()
		{
			(dock.layout_manager as BoxLayout).spacing = (uint)(dock_theme.ItemPadding / 10.0 * dock_settings.IconSize);
			dock.height = dock_settings.IconSize;
			
			var top_offset = (int)(dock_theme.TopPadding / 10.0 * dock_settings.IconSize);
			var bottom_offset = (int)(dock_theme.BottomPadding / 10.0 * dock_settings.IconSize);
			
			y_constraint.offset = -top_offset / 2 + bottom_offset / 2;
			h_constraint.offset = top_offset + bottom_offset;
		}
		
		bool draw_dock_background (Cairo.Context cr)
		{
			if (dock_surface == null || dock_surface.Width != dock_background.width) {
				dock_surface = dock_theme.create_background ((int)dock_background.width,
					(int)dock_background.height, Gtk.PositionType.BOTTOM,
					new Plank.Drawing.DockSurface.with_surface (1, 1, cr.get_target ()));
			}
			
			cr.set_source_surface (dock_surface.Internal, 0, 0);
			cr.paint ();
			
			return false;
		}
		
		public override bool key_release_event (Clutter.KeyEvent event)
		{
			if (((event.modifier_state & ModifierType.MOD1_MASK) == 0) || 
					event.keyval == Key.Alt_L) {
				close (event.time);
			}
			
			return true;
		}
		
		void close (uint time)
		{
			if (closing)
				return;

			closing = true;

			var screen = plugin.get_screen ();
			
			var workspace = screen.get_active_workspace ();
			workspace.window_added.disconnect (add_window);
			workspace.window_removed.disconnect (remove_window);
			
			if (dock_window != null)
				dock_window.opacity = 0;
			
			var dest_width = (dock_width > 0 ? dock_width : 600.0f);
			dock_width = 0;
			
			set_child_above_sibling (dock, null);
			dock_background.animate (AnimationMode.EASE_OUT_CUBIC, 250, opacity : 0);
			
			if (dock_window != null) {
				dock_window.show ();
				dock_window.animate (AnimationMode.LINEAR, 250, opacity : 255);
			}
			
			foreach (var clone in window_clones) {
				//current window stays on top
				if ((clone.source as Meta.WindowActor).get_meta_window () == current_window)
					continue;
				
				//reset order
				clone.get_parent ().set_child_below_sibling (clone, null);
				clone.animate (AnimationMode.EASE_OUT_CUBIC, 150, depth : 0.0f, opacity : 255);
			}
			
			if (current_window != null) {
				current_window.activate (time);
				current_window = null;
			}
			
			plugin.end_modal ();
			
			dock.animate (AnimationMode.EASE_OUT_CUBIC, 250, width:dest_width, opacity : 0).
				completed.connect (() => {
				dock.remove_all_children ();
				
				if (dock_window != null)
					dock_window = null;
				
				visible = false;
				
				foreach (var clone in window_clones)
					remove_clone (clone);
				window_clones.clear ();
				
				//need to go through all the windows because of hidden dialogs
				foreach (var window in Meta.Compositor.get_window_actors (screen)) {
					if (window.get_workspace () == workspace.index ())
						window.show ();
				}
			});
		}
		
		//used to figure out delays between switching when holding the tab key
		uint last_time = -1;
		bool released = false;
		public override bool captured_event (Clutter.Event event)
		{
			var screen = plugin.get_screen ();
			var display = screen.get_display ();
			
			if (event.get_type () == EventType.KEY_RELEASE) {
				released = true;
				return false;
			}
			
			if (!(event.get_type () == EventType.KEY_PRESS) || 
				(!released && display.get_current_time_roundtrip () < (last_time + 300)))
				return false;
			
			released = false;
			
			bool backward = (event.get_state () & X.KeyMask.ShiftMask) != 0;
			var action = display.get_keybinding_action (event.get_key_code (), event.get_state ());
			
			var prev_win = current_window;
			if (action == Meta.KeyBindingAction.SWITCH_GROUP ||
				action == Meta.KeyBindingAction.SWITCH_WINDOWS || 
				event.get_key_symbol () == Clutter.Key.Right) {
				
				current_window = display.get_tab_next (Meta.TabList.NORMAL, screen, 
						screen.get_active_workspace (), current_window, backward);
				last_time = display.get_current_time_roundtrip ();
				
			} else if (action == Meta.KeyBindingAction.SWITCH_GROUP_BACKWARD ||
				action == Meta.KeyBindingAction.SWITCH_WINDOWS_BACKWARD ||
				event.get_key_symbol () == Clutter.Key.Left) {
				
				current_window = display.get_tab_next (Meta.TabList.NORMAL, screen, 
						screen.get_active_workspace (), current_window, true);
				last_time = display.get_current_time_roundtrip ();
			}
			
			if (prev_win != current_window) {
				dim_windows ();
			}
			
			return true;
		}

		bool clicked_icon (Clutter.ButtonEvent event) {
			var index = 0;
			for (; index < dock.get_n_children (); index++) {
				if (dock.get_child_at_index (index) == event.source)
					break;
			}
			
			var prev_window = current_window;
			current_window = (window_clones.get (index).source as Meta.WindowActor).get_meta_window ();
			
			if (prev_window != current_window) {
				dim_windows ();
				// wait for the dimming to finish
				Timeout.add (250, () => {
					close (event.time);
					return false;
				});
			} else {
				close (event.time);
			}

			return true;
		}
		
		void dim_windows ()
		{
			var current_actor = current_window.get_compositor_private () as Actor;
			var i = 0;
			foreach (var clone in window_clones) {
				if (current_actor == clone.source) {
					set_child_below_sibling (clone, dock_background);
					clone.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, depth : 0.0f, opacity : 255);
					
					dock.get_child_at_index (i).animate (AnimationMode.LINEAR, 100, opacity : 255);
				} else {
					clone.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, depth : -200.0f, opacity : 0);
					dock.get_child_at_index (i).animate (AnimationMode.LINEAR, 100, opacity : 100);
				}
				
				i++;
			}
		}
		
		void add_window (Meta.Window window)
		{
			var screen = plugin.get_screen ();
			
			if (window.get_workspace () != screen.get_active_workspace ())
				return;
			
			var actor = window.get_compositor_private () as Meta.WindowActor;
			if (actor == null) {
				//the window possibly hasn't reached the compositor yet
				Idle.add (() => {
					if (window.get_compositor_private () != null &&
						window.get_workspace () == screen.get_active_workspace ())
						add_window (window);
					return false;
				});
				return;
			}
			
			if (actor.is_destroyed ())
				return;
			
			actor.hide ();
			
			var clone = new Clone (actor);
			clone.x = actor.x;
			clone.y = actor.y;
			
			add_child (clone);
			window_clones.add (clone);
			
			var icon = new GtkClutter.Texture ();
			icon.reactive = true;
			icon.button_release_event.connect (clicked_icon);
			try {
				icon.set_from_pixbuf (Utils.get_icon_for_window (window, dock_settings.IconSize));
			} catch (Error e) { warning (e.message); }
			
			icon.opacity = 100;
			dock.add_child (icon);
			(dock.layout_manager as BoxLayout).set_expand (icon, true);
			
			//if the window has been added while being in alt-tab, redim
			if (visible) {
				float dest_width;
				dock.layout_manager.get_preferred_width (dock, dock.height, null, out dest_width);
				dock.animate (AnimationMode.EASE_OUT_CUBIC, 400, width : dest_width);
				dim_windows ();
			}
		}
		
		void remove_clone (Clone clone)
		{
			var window = clone.source as Meta.WindowActor;
			
			var meta_win = window.get_meta_window ();
			if (meta_win != null &&
				!window.is_destroyed () &&
				!meta_win.minimized &&
				(meta_win.get_workspace () == plugin.get_screen ().get_active_workspace ()) ||
				meta_win.is_on_all_workspaces ())
				window.show ();
			
			clone.destroy ();
			
			float dest_width;
			dock.layout_manager.get_preferred_width (dock, dock.height, null, out dest_width);
			dock.animate (AnimationMode.EASE_OUT_CUBIC, 400, width : dest_width);
		}
		
		void remove_window (Meta.Window window)
		{
			Clone found = null;
			foreach (var clone in window_clones) {
				if ((clone.source as Meta.WindowActor).get_meta_window () == window) {
					found = clone;
					break;
				}
			}
			
			if (found == null) {
				warning ("No clone found for removed window");
				return;
			}
			
			var icon = dock.get_child_at_index (window_clones.index_of (found));
			icon.button_release_event.disconnect (clicked_icon);
			icon.destroy ();
			window_clones.remove (found);
			remove_clone (found);
		}
		
		public override void key_focus_out ()
		{
			close (plugin.get_screen ().get_display ().get_current_time ());
		}
		
		public void handle_switch_windows (Meta.Display display, Meta.Screen screen, Meta.Window? window,
			X.Event event, Meta.KeyBinding binding)
		{
			if (visible) {
				if (window_clones.size != 0)
					close (screen.get_display ().get_current_time ());
				return;
			}
			
			var workspace = screen.get_active_workspace ();
			
			var metawindows = display.get_tab_list (Meta.TabList.NORMAL, screen, workspace);
			if (metawindows.length () == 0)
				return;
			if (metawindows.length () == 1) {
				var win = metawindows.nth_data (0);
				var actor = win.get_compositor_private () as Actor;
				if (actor.is_in_clone_paint ())
					return;
				
				win.activate (display.get_current_time ());

				if (win.minimized)
					win.unminimize ();

				actor.hide ();
				
				var clone = new Clone (actor);
				clone.x = actor.x;
				clone.y = actor.y;
				Meta.Compositor.get_overlay_group_for_screen (screen).add_child (clone);
				clone.animate (Clutter.AnimationMode.LINEAR, 100, depth : -50.0f).completed.connect (() => {
					clone.animate (Clutter.AnimationMode.LINEAR, 300, depth : 0.0f);
				});
				
				Timeout.add (410, () => {
					actor.show ();
					clone.destroy ();
					
					return false;
				});
				
				return;
			}
			
			workspace.window_added.connect (add_window);
			workspace.window_removed.connect (remove_window);
			
			//grab the windows to be switched
			var layout = dock.layout_manager as BoxLayout;
			window_clones.clear ();
			foreach (var win in metawindows)
				add_window (win);
			
			visible = true;
			
			//hide the others
			Meta.Compositor.get_window_actors (screen).foreach ((w) => {
				var type = w.get_meta_window ().window_type;
				if (type != Meta.WindowType.DOCK && type != Meta.WindowType.DESKTOP && type != Meta.WindowType.NOTIFICATION)
					w.hide ();
				
				if (w.get_meta_window ().title in BehaviorSettings.get_default ().dock_names && type == Meta.WindowType.DOCK) {
					dock_window = w;
					dock_window.hide ();
				}
			});
			
			closing = false;
			plugin.begin_modal ();
			
			bool backward = (binding.get_name () == "switch-windows-backward");
			
			current_window = Utils.get_next_window (screen.get_active_workspace (), backward);
			if (current_window == null)
				return;
			
			if (binding.get_mask () == 0) {
				current_window.activate (display.get_current_time ());
				return;
			}
			
			//plank type switcher thing
			var geometry = screen.get_monitor_geometry (screen.get_primary_monitor ());
			
			dock.width = (dock_window != null ? dock_window.width : 300.0f);
			//FIXME do this better
			//count the launcher items to get an estimate of the window size
			var launcher_folder = Plank.Services.Paths.AppConfigFolder.get_child ("dock1").get_child ("launchers");
			if (launcher_folder.query_exists ()) {
				try {
					int count = 0;
					var children = launcher_folder.enumerate_children ("", 0);
					while (children.next_file () != null)
						count ++;
					
					if (count > 0)
						dock.width = count * (float)(dock_settings.IconSize + dock_theme.ItemPadding);
					
					dock_width = dock.width;
					
				} catch (Error e) { warning (e.message); }
			}
			
			
			var bottom_offset = (int)(dock_theme.BottomPadding / 10.0 * dock_settings.IconSize);
			dock.opacity = 255;
			dock.x = Math.ceilf (geometry.x + geometry.width / 2.0f);
			dock.y = Math.ceilf (geometry.y + geometry.height - dock.height / 2.0f) - bottom_offset;
			
			//add spacing on outer most items
			var horiz_padding = (float) Math.ceil (dock_theme.HorizPadding / 10.0 * dock_settings.IconSize + layout.spacing / 2.0);
			dock.get_first_child ().margin_left = horiz_padding;
			dock.get_last_child ().margin_right = horiz_padding;
			
			float dest_width;
			layout.get_preferred_width (dock, dock.height, null, out dest_width);
			
			set_child_above_sibling (dock_background, null);
			dock_background.opacity = 255;
			dock.animate (AnimationMode.EASE_OUT_CUBIC, 250, width : dest_width);
			set_child_above_sibling (dock, null);
			
			dim_windows ();
			grab_key_focus ();
		}
	}
}
