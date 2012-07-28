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
		
		//switcher is currently running
		bool active;
		
		CairoTexture plank_background;
		Actor plank_box;
		int plank_size;
		Meta.WindowActor? dock_window;
		
		//FIXME window titles of supported docks, to be extended
		const string [] DOCK_NAMES = {"plank", "Docky"};
		
		public WindowSwitcher (Gala.Plugin _plugin)
		{
			plugin = _plugin;
			
			//have a look at plank configs if they're available for the icon-size, otherwise we'll use 48
			plank_size = 48;
			try {
				var configs = new KeyFile ();
				configs.load_from_file (Environment.get_user_config_dir () + "/plank/dock1/settings", 0);
				plank_size = configs.get_integer ("PlankDockPreferences", "IconSize");
			} catch (Error e) { error (e.message); }
			
			var layout = new BoxLayout ();
			
			plank_box = new Actor ();
			plank_box.layout_manager = layout;
			plank_box.height = plank_size;
			plank_box.anchor_gravity = Clutter.Gravity.CENTER;
			
			layout.spacing = 6;
			
			plank_background = new CairoTexture (100, plank_size);
			plank_background.anchor_gravity = Clutter.Gravity.CENTER;
			plank_background.auto_resize = true;
			plank_background.draw.connect (draw_plank_background);
			plank_background.add_constraint (new BindConstraint (plank_box, BindCoordinate.X, 0));
			plank_background.add_constraint (new BindConstraint (plank_box, BindCoordinate.Y, 2));
			plank_background.add_constraint (new BindConstraint (plank_box, BindCoordinate.WIDTH, 0));
			plank_background.add_constraint (new BindConstraint (plank_box, BindCoordinate.HEIGHT, 0));
			
			add_child (plank_background);
			add_child (plank_box);
			
			visible = false;
		}
		
		bool draw_plank_background (Cairo.Context cr)
		{
			Utilities.cairo_rounded_rectangle (cr, 0, plank_size * 0.6, plank_background.width, plank_size, 5);
			
			cr.set_source_rgba (1, 1, 1, 0.8);
			cr.fill_preserve ();
			cr.set_source_rgba (0, 0, 0, 0.5);
			cr.stroke ();
			
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
			foreach (var clone in window_clones) {
				remove_child (clone);
				clone.destroy ();
			}
			
			Meta.Compositor.get_window_actors (plugin.get_screen ()).foreach ((w) => {
				var meta_win = w.get_meta_window ();
				if (!meta_win.minimized && 
					(meta_win.get_workspace () == plugin.get_screen ().get_active_workspace ()) || 
					meta_win.is_on_all_workspaces ())
					w.show ();
			});
			if (dock_window != null)
				dock_window.opacity = 0;
			
			window_clones.clear ();
			
			plugin.end_modal ();
			if (current_window != null) {
				current_window.activate (time);
				current_window = null;
			}
			
			var dest_width = (dock_window!=null)?dock_window.width:800.0f;
			
			plank_box.get_parent ().set_child_above_sibling (plank_box, null);
			plank_background.animate (AnimationMode.EASE_OUT_CUBIC, 250, opacity:0);
			
			if (dock_window != null)
				dock_window.animate (AnimationMode.LINEAR, 250, opacity:255);
			
			plank_box.animate (AnimationMode.EASE_OUT_CUBIC, 250, width:dest_width, opacity:0).
				completed.connect (() => {
				plank_box.remove_all_children ();
				
				if (dock_window != null)
					dock_window = null;
				
				visible = false;
			});
			
			active = false;
		}
		
		public override bool captured_event (Clutter.Event event)
		{
			if (!(event.get_type () == EventType.KEY_PRESS))
				return false;
			
			var screen = plugin.get_screen ();
			var display = screen.get_display ();
			
			bool backward = (event.get_state () & X.KeyMask.ShiftMask) != 0;
			var action = display.get_keybinding_action (event.get_key_code (), event.get_state ());
			
			var prev_win = current_window;
			switch (action) {
				case Meta.KeyBindingAction.SWITCH_GROUP:
				case Meta.KeyBindingAction.SWITCH_WINDOWS:
					current_window = display.get_tab_next (Meta.TabList.NORMAL, screen, 
							screen.get_active_workspace (), current_window, backward);
					break;
				case Meta.KeyBindingAction.SWITCH_GROUP_BACKWARD:
				case Meta.KeyBindingAction.SWITCH_WINDOWS_BACKWARD:
					current_window = display.get_tab_next (Meta.TabList.NORMAL, screen, 
							screen.get_active_workspace (), current_window, true);
					break;
				default:
					break;
			}
			
			if (prev_win != current_window) {
				dim_windows ();
			}
			
			return true;
		}
		
		void dim_windows ()
		{
			var current_actor = current_window.get_compositor_private () as Actor;
			var i = 0;
			foreach (var clone in window_clones) {
				if (current_actor == clone.source) {
					clone.get_parent ().set_child_below_sibling (clone, null);
					clone.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, depth : 0.0f, opacity : 255);
					
					plank_box.get_child_at_index (i).animate (AnimationMode.LINEAR, 100, opacity:255);
				} else {
					clone.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, depth : -200.0f, opacity : 0);
					plank_box.get_child_at_index (i).animate (AnimationMode.LINEAR, 100, opacity:100);
				}
				
				i ++;
			}
		}
		
		public void handle_switch_windows (Meta.Display display, Meta.Screen screen, Meta.Window? window,
			X.Event event, Meta.KeyBinding binding)
		{
			if (active) {
				if (window_clones.size != 0)
					close (screen.get_display ().get_current_time ());
				return;
			}
			
			var metawindows = display.get_tab_list (Meta.TabList.NORMAL, screen, screen.get_active_workspace ());
			if (metawindows.length () <= 1)
				return;
			
			active = true;
			visible = true;
			
			window_clones.clear ();
			
			foreach (var win in metawindows) {
				var actor = win.get_compositor_private () as Actor;
				var clone = new Clone (actor);
				clone.x = actor.x;
				clone.y = actor.y;
				
				var icon = new GtkClutter.Texture ();
				try {
					icon.set_from_pixbuf (Utils.get_icon_for_window (win, plank_size));
				} catch (Error e) { warning (e.message); }
				
				icon.opacity = 100;
				plank_box.add_child (icon);
				(plank_box.layout_manager as BoxLayout).set_expand (icon, true);
				
				add_child (clone);
				window_clones.add (clone);
			}
			
			Meta.Compositor.get_window_actors (screen).foreach ((w) => {
				var type = w.get_meta_window ().window_type;
				if ((type != Meta.WindowType.DOCK && type != Meta.WindowType.DESKTOP && type != Meta.WindowType.NOTIFICATION) ||
					w.get_meta_window ().title in DOCK_NAMES)
					w.hide ();
				if (w.get_meta_window ().title in DOCK_NAMES)
					dock_window = w;
			});
			
			plugin.begin_modal ();
			
			bool backward = (binding.get_name () == "switch-windows-backward");
			
			/*list windows*/
			current_window = Utils.get_next_window (screen.get_active_workspace (), backward);
			if (current_window == null)
				return;
			
			if (binding.get_mask () == 0) {
				current_window.activate (display.get_current_time ());
				return;
			}
			
			/*plank type switcher thing*/
			var geometry = screen.get_monitor_geometry (screen.get_primary_monitor ());
			
			if (dock_window != null)
				plank_box.width = dock_window.width;
			
			plank_box.opacity = 255;
			plank_box.x = geometry.x + Math.ceilf (geometry.width/2);
			plank_box.y = geometry.y + geometry.height - plank_box.height/2 - 2;
			
			float dest_width;
			plank_box.layout_manager.get_preferred_width (plank_box, plank_box.height, null, out dest_width);
			
			plank_background.get_parent ().set_child_above_sibling (plank_background, null);
			plank_background.opacity = 255;
			plank_box.animate (AnimationMode.EASE_OUT_CUBIC, 250, width:dest_width);
			plank_box.get_parent ().set_child_above_sibling (plank_box, null);
			
			dim_windows ();
			grab_key_focus ();
		}
	}
}
