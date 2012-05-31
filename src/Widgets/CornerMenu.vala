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

namespace Gala
{
	public class CornerMenu : Clutter.Group
	{
		Gala.Plugin plugin;
		
		Clutter.Box workspaces;
		
		bool animating; // delay closing the popup
		
		public CornerMenu (Gala.Plugin _plugin)
		{
			plugin = _plugin;
		
			width  = 100;
			height = 100;
			opacity = 0;
			scale_gravity = Clutter.Gravity.SOUTH_EAST;
			scale_x = scale_y = 0.0f;
			reactive = true;
		
			workspaces = new Clutter.Box (new Clutter.BoxLayout ());
			(workspaces.layout_manager as Clutter.BoxLayout).spacing = 15;
			(workspaces.layout_manager as Clutter.BoxLayout).vertical = true;
		
			leave_event.connect ((e) => {
				if (get_children ().index (e.related) == -1)
					hide ();
			
				return false;
			});
		
			var tile = new GtkClutter.Texture ();
			try {
				tile.set_from_pixbuf (Gtk.IconTheme.get_default ().load_icon ("preferences-desktop-display", 64, 0));
			} catch (Error e) {
				warning (e.message);
			}
		
			tile.x = 5;
			tile.y = 5;
			tile.reactive = true;
			tile.button_release_event.connect (() => {
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
		
			add_child (tile);
			//add_child (workspaces);
		}
	
		public new void show ()
		{
			if (visible)
				return;
			
			plugin.set_input_area (Gala.InputArea.FULLSCREEN);
			plugin.begin_modal ();
			
			animating = true;
			
			int width, height;
			plugin.get_screen ().get_size (out width, out height);
			x = width - this.width;
			y = height - this.height;
			
			visible = true;
			grab_key_focus ();
			animate (Clutter.AnimationMode.EASE_OUT_BOUNCE, 400, scale_x:1.0f, scale_y:1.0f, opacity:255).completed.connect (() => {
				animating = false;
			});
		}
	
		public new void hide ()
		{
			if (!visible || animating)
				return;
			
			plugin.end_modal ();
			plugin.set_input_area (Gala.InputArea.HOT_CORNER);
			
			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, scale_x : 0.0f, scale_y : 0.0f, opacity : 0)
				.completed.connect ( () => {
				visible = false;
			});
		}
	}
}
