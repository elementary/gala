//  
//  Copyright (C) 2012 Tom Beckmann
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
using Clutter;

namespace Gala
{
	public class Expo : Actor
	{
		
		Plugin plugin;
		Screen screen;
		
		bool ready;
		
		public Expo (Plugin _plugin)
		{
			plugin = _plugin;
			screen = plugin.get_screen ();
			
			screen.workspace_switched.connect (() => close (false) );
			
			visible = false;
			ready = true;
		}
		
		public override bool key_press_event (Clutter.KeyEvent event)
		{
			//FIXME need to figure out the actual keycombo, for now leave it by default and others will close it by selecting a window!
			if (event.keyval == Clutter.Key.e) {
				close (true);
				
				return true;
			}
			
			return false;
		}
		
		public override void key_focus_out ()
		{
			close (false);
		}
		
		//vala doesnt support multidimensional array of different sizes, that's why we fill them up with 0s
		static float [,,] POSITIONS = {
			{{0.0f, 0.0f, 1.0f, 1.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}},
			{{0.0f, 0.0f, 0.5f, 1.0f}, {0.5f, 0.0f, 0.5f, 1.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}},
			{{0.0f, 0.0f, 0.5f, 0.5f}, {0.5f, 0.0f, 0.5f, 0.5f}, {0.0f, 0.5f, 1.0f, 0.5f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}},
			{{0.0f, 0.0f, 0.5f, 0.5f}, {0.5f, 0.0f, 0.5f, 0.5f}, {0.0f, 0.5f, 0.5f, 0.5f}, {0.5f, 0.5f, 0.5f, 0.5f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}},
			{{0.0f, 0.0f, 0.3f, 0.5f}, {0.3f, 0.0f, 0.3f, 0.5f}, {0.6f, 0.0f, 0.3f, 0.5f}, {0.0f, 0.5f, 0.5f, 0.5f}, {0.5f, 0.5f, 0.5f, 0.5f}, {0.0f, 0.0f, 0.0f, 0.0f}},
			{{0.0f, 0.0f, 0.3f, 0.5f}, {0.3f, 0.0f, 0.3f, 0.5f}, {0.6f, 0.0f, 0.3f, 0.5f}, {0.0f, 0.5f, 0.3f, 0.5f}, {0.3f, 0.5f, 0.3f, 0.5f}, {0.6f, 0.5f, 0.3f, 0.5f}}
		};
		
		public void open (bool animate=true)
		{
			if (!ready)
				return;
			
			if (visible) {
				close ();
				return;
			}
			
			ready = false;
			
			var monitor = screen.get_monitor_geometry (screen.get_primary_monitor ());
			Meta.Rectangle workarea = {monitor.x + 50, monitor.y + 50, monitor.width - 100, monitor.height - 150};
			
			var used_windows = new SList<Window> ();
			
			screen.get_active_workspace ().list_windows ().foreach ((w) => {
				if (w.window_type != Meta.WindowType.NORMAL || w.minimized)
					return;
				used_windows.append (w);
			});
			
			var windows = screen.get_display ().sort_windows_by_stacking (used_windows);
			
			var n_windows = used_windows.length ();
			if (n_windows == 0)
				return;
			
			grab_key_focus ();
			
			var rows = (int)Math.ceilf (Math.sqrtf (n_windows));
			var cols = (int)Math.ceilf (n_windows / (float)rows);
			
			plugin.begin_modal ();
			Utils.set_input_area (screen, InputArea.FULLSCREEN);
			
			visible = true;
			
			var i = 0;
			windows.foreach ((w) => {
				var actor = w.get_compositor_private () as WindowActor;
				if (actor == null)
					return;
				actor.hide ();
				
				var clone = new ExposedWindow (w);
				
				clone.selected.connect (selected);
				
				clone.x = actor.x;
				clone.y = actor.y;
				
				//calculate new rect
				float scale_x = 1.0f;
				float scale_y = 1.0f;
				float dest_w = actor.width;
				float dest_h = actor.height;
				float dest_x, dest_y, max_width, max_height;
				
				if (n_windows > POSITIONS.length[0]) {
					max_width  = workarea.width  / cols - 50;
					max_height = workarea.height / rows - 50;
					
					dest_x = workarea.x + workarea.width  * ((i % rows) / (float)rows);
					dest_y = workarea.y + workarea.height * Math.floorf ((i / (float)rows)) / (float)cols;
				} else {
					max_width  = workarea.width  * POSITIONS[n_windows-1,i,2] - 50;
					max_height = workarea.height * POSITIONS[n_windows-1,i,3] - 50;
					
					dest_x = workarea.x + workarea.width  * POSITIONS[n_windows-1,i,0];
					dest_y = workarea.y + workarea.height * POSITIONS[n_windows-1,i,1];
				}
				
				if (dest_w > max_width || dest_h > max_height) {
					var aspect = (max_width / dest_w < max_height / dest_h) ? max_width / dest_w : max_height / dest_h;
					dest_w = dest_w * aspect;
					dest_h = dest_h * aspect;
					scale_x = (dest_w) / actor.width;
					scale_y = (dest_h) / actor.height;
				}
				
				dest_x += max_width  / 2 - dest_w / 2; //center them
				dest_y += max_height / 2 - dest_h / 2;
				
				clone.icon.x = dest_x + (clone.width * scale_x) / 2 - clone.icon.width/2;
				clone.icon.y = dest_y + clone.height*scale_y - 30;
				clone.icon.get_parent ().set_child_above_sibling (clone.icon, null);
				
				if (animate) {
					clone.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 250, scale_x:scale_x, scale_y:scale_y, x:dest_x, y:dest_y);
					clone.icon.opacity = 0;
					clone.icon.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 350, scale_x:1.0f, scale_y:1.0f, opacity:255).completed.connect (() => {
						ready = true;
					});
				} else {
					clone.scale_x = scale_x;
					clone.scale_y = scale_y;
					clone.x = dest_x;
					clone.y = dest_y;
					
					clone.icon.scale_x = 1.0f;
					clone.icon.scale_y = 1.0f;
				}
				
				add_child (clone);
				
				i ++;
			});
		}
		
		void selected (Window window)
		{
			window.activate (screen.get_display ().get_current_time ());
			
			close (true);
		}
		
		void close (bool animate = true)
		{
			if (!visible || !ready)
				return;
			
			ready = false;
			
			plugin.end_modal ();
			plugin.update_input_area ();
			
			get_children ().foreach ( (c) => {
				var exposed = c as ExposedWindow;
				exposed.close (animate);
				exposed.selected.disconnect (selected);
			});
			
			if (animate) {
				Timeout.add (250, () => {
					visible = false;
					ready = true;
					
					return false;
				});
			} else {
				ready = true;
				visible = false;
			}
		}
	}
}
