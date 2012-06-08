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

/*
NOTE:
The actual switcher is not shown anymore
*/

using Clutter;
using Granite.Drawing;

namespace Gala
{
	public class WindowSwitcher : Clutter.Actor
	{
		const int ICON_SIZE = 128;
		const int spacing = 12;
			
		Gala.Plugin plugin;
		
		GLib.List<unowned Meta.Window> window_list;
		
		CairoTexture background;
		CairoTexture current;
		Text title;
		
		int _windows = 1;
		int windows {
			get { return _windows; }
			set {
				_windows = value;
				width = spacing + _windows * (ICON_SIZE + spacing);
			}
		}
		
		Meta.Window? _current_window;
		Meta.Window? current_window {
			get { return _current_window; }
			set {
				_current_window = value;
				title.text = current_window.title;
				title.x = (int)(width / 2 - title.width / 2);
			}
		}
		
		public WindowSwitcher (Gala.Plugin _plugin)
		{
			plugin = _plugin;
			
			height = ICON_SIZE + spacing * 2;
			opacity = 0;
			scale_gravity = Gravity.CENTER;
			
			background = new CairoTexture (100, 100);
			background.auto_resize = true;
			background.draw.connect (draw_background);
			
			current = new CairoTexture (ICON_SIZE, ICON_SIZE);
			current.y = spacing + 1;
			current.x = spacing + 1;
			current.width = ICON_SIZE;
			current.height = ICON_SIZE;
			current.auto_resize = true;
			current.draw.connect (draw_current);
			
			windows = 1;
			
			title = new Text.with_text ("bold 16px", "");
			title.y = ICON_SIZE + spacing * 2 + 6;
			title.color = {255, 255, 255, 255};
			title.add_effect (new TextShadowEffect (1, 1, 220));
			
			background.add_constraint (new BindConstraint (this, BindCoordinate.WIDTH, 0));
			background.add_constraint (new BindConstraint (this, BindCoordinate.HEIGHT, 0));
		}
		
		public override bool key_release_event (Clutter.KeyEvent event)
		{
			if (((event.modifier_state & ModifierType.MOD1_MASK) == 0) || 
					event.keyval == Key.Alt_L) {
				
				window_list.foreach ((w) => {
					plugin.dim_window (w, false);
					(w.get_compositor_private () as Clutter.Actor).detach_animation ();
					(w.get_compositor_private () as Clutter.Actor).depth = 0.0f;
				});
				
				plugin.end_modal ();
				current_window.activate (event.time);
				
				animate (AnimationMode.EASE_OUT_QUAD, 200, opacity : 0);
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
			
			current.animate (AnimationMode.EASE_OUT_QUAD, 200,
				x : 0.0f + spacing + window_list.index (current_window) * (spacing + ICON_SIZE));
			
			if (prev_win != current_window) {
				dim_windows ();
			}
			
			return true;
		}
		
		bool draw_background (Cairo.Context cr)
		{
			Utilities.cairo_rounded_rectangle (cr, 0.5, 0.5, width - 1, height - 1, 10);
			cr.set_line_width (1);
			cr.set_source_rgba (0, 0, 0, 0.5);
			cr.stroke_preserve ();
			cr.set_source_rgba (1, 1, 1, 0.4);
			cr.fill ();
			
			return true;
		}
		
		bool draw_current (Cairo.Context cr)
		{
			Utilities.cairo_rounded_rectangle (cr, 0.5, 0.5, current.width - 2, current.height - 1, 10);
			cr.set_line_width (1);
			cr.set_source_rgba (0, 0, 0, 0.9);
			cr.stroke_preserve ();
			cr.set_source_rgba (1, 1, 1, 0.9);
			cr.fill ();
			
			return true;
		}
		
		void dim_windows ()
		{
			window_list.foreach ((window) => {
				//	(window.get_compositor_private () as Clutter.Actor).animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, depth:-80.0f);
				plugin.dim_window (window, window != current_window);
			});
			
			(current_window.get_compositor_private () as Clutter.Actor).raise_top ();
			(current_window.get_compositor_private () as Clutter.Actor).depth = -80.0f;
			(current_window.get_compositor_private () as Clutter.Actor).animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, depth:0.0f);
		}
		
		void list_windows (Meta.Display display, Meta.Screen screen, Meta.KeyBinding binding, bool backward)
		{
			remove_all_children ();
			
			add_child (background);
			add_child (current);
			add_child (title);
			
			current_window = plugin.get_next_window (screen.get_active_workspace (), backward);
			if (current_window == null)
				return;
			
			if (binding.get_mask () == 0) {
				current_window.activate (display.get_current_time ());
				return;
			}
			
			var i = 0;
			window_list = display.get_tab_list (Meta.TabList.NORMAL, screen, screen.get_active_workspace ());
			
			foreach (var window in window_list) {
				var image = Gala.Plugin.get_icon_for_window (window, ICON_SIZE);
				
				var icon = new GtkClutter.Texture ();
				try {
					icon.set_from_pixbuf (image);
				} catch (Error e) {
					warning (e.message);
				}
				
				icon.x = spacing + 5 + i * (spacing + ICON_SIZE);
				icon.y = spacing + 5;
				icon.width = ICON_SIZE - 10;
				icon.height = ICON_SIZE - 10;
				
				add_child (icon);
				
				i++;
			}
			
			windows = i;
			
			var idx = window_list.index (current_window);
			current.x = spacing + idx * (spacing + ICON_SIZE);
			
			dim_windows ();
		}
		
		public void handle_switch_windows (Meta.Display display, Meta.Screen screen, Meta.Window? window,
			X.Event event, Meta.KeyBinding binding)
		{
			if (display.get_tab_list (Meta.TabList.NORMAL, screen, screen.get_active_workspace ()).length () == 0)
				return;
			
			plugin.begin_modal ();
			
			var area = screen.get_monitor_geometry (screen.get_primary_monitor ());
			
			bool backward = (binding.get_name () == "switch-windows-backward");
			list_windows (display, screen, binding, backward);
			
			x = area.width / 2 - width / 2;
			y = area.height / 2 - height / 2;
			grab_key_focus ();
			//animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, opacity : 255);
		}
	}
}
