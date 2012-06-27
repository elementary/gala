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
		
		GLib.List<unowned Meta.Window>? window_list = null;
		
		Meta.Window? current_window;
		
		public WindowSwitcher (Gala.Plugin _plugin)
		{
			plugin = _plugin;
		}
		
		public override bool key_release_event (Clutter.KeyEvent event)
		{
			if (((event.modifier_state & ModifierType.MOD1_MASK) == 0) || 
					event.keyval == Key.Alt_L) {
				
				plugin.get_screen ().get_active_workspace ().list_windows ().foreach ((window) => {
					var actor = window.get_compositor_private () as Clutter.Actor;
					if (actor == null)
						return;
					
					if (window.minimized)
						actor.hide ();
					
					actor.detach_animation ();
					actor.depth = 0.0f;
					actor.opacity = 255;
				});
				
				window_list = null;
				
				plugin.end_modal ();
				current_window.activate (event.time);
			}
			
			return true;
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
			window_list.foreach ((window) => {
				if (window.window_type != Meta.WindowType.NORMAL)
					return;
				
				var actor = window.get_compositor_private () as Clutter.Actor;
				if (actor == null)
					return;
				
				if (window.minimized)
					actor.show ();
				
				if (window == current_window) {
					actor.get_parent ().set_child_above_sibling (actor, null);
					actor.depth = -200.0f;
					actor.opacity = 0;
					actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, depth : 0.0f, opacity : 255);
				} else {
					actor.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, depth : -200.0f, opacity : 0);
				}
			});
		}
		
		public void handle_switch_windows (Meta.Display display, Meta.Screen screen, Meta.Window? window,
			X.Event event, Meta.KeyBinding binding)
		{
			window_list = display.get_tab_list (Meta.TabList.NORMAL, screen, screen.get_active_workspace ());
			if (window_list.length () <= 1) {
				window_list = null;
				return;
			}
			
			plugin.begin_modal ();
			
			bool backward = (binding.get_name () == "switch-windows-backward");
			
			/*list windows*/
			var workspace = screen.get_active_workspace ();
			
			current_window = plugin.get_next_window (workspace, backward);
			if (current_window == null)
				return;
			
			if (binding.get_mask () == 0) {
				current_window.activate (display.get_current_time ());
				return;
			}
			
			//hide dialogs
			workspace.list_windows ().foreach ((w) => {
				if (w.window_type == Meta.WindowType.DIALOG ||
					w.window_type == Meta.WindowType.MODAL_DIALOG)
						(w.get_compositor_private () as Clutter.Actor).opacity = 0;
			});
			
			dim_windows ();
			
			grab_key_focus ();
		}
	}
}
