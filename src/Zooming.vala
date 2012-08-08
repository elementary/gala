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

using Clutter;
using Meta;

namespace Gala
{

	public class Zooming : Object
	{
		
		Plugin plugin;
		
		bool active;
		uint mouse_poll;
		
		public Zooming (Plugin _plugin)
		{
			plugin = _plugin;
			
			active = false;
		}
		
		void end ()
		{
			if (!active)
				return;
			
			active = false;
			
			var wins = Compositor.get_window_group_for_screen (plugin.get_screen ());
			wins.animate (AnimationMode.EASE_OUT_CUBIC, 300, scale_x:1.0, scale_y:1.0).completed.connect (() => {
				wins.scale_center_x = 0.0f;
				wins.scale_center_y = 0.0f;
			});
			
			Source.remove (mouse_poll);
		}
		
		public void zoom (bool in)
		{
			var wins = Compositor.get_window_group_for_screen (plugin.get_screen ());
			
			//setup things
			if (in && !active) {
				int mx, my;
				Gdk.Display.get_default ().get_device_manager ().get_client_pointer ().get_position (null, out mx, out my);
				wins.scale_center_x = mx;
				wins.scale_center_y = my;
				
				active = true;
				
				mouse_poll = Timeout.add (50, () => {
					float x, y;
					Gdk.Display.get_default ().get_device_manager ().get_client_pointer ().get_position (null, out x, out y);
					
					wins.animate (Clutter.AnimationMode.LINEAR, 50, scale_center_x : x);
					wins.animate (Clutter.AnimationMode.LINEAR, 50, scale_center_y : y);
					
					return true;
				});
			}
			
			if (!active)
				return;
			
			var new_val = wins.scale_x - ( in ? -0.5 : 0.5);
			
			//because of the animation, we might stop a bit before 1.0 accidentally
			if (new_val <= 1.25) {
				end ();
				return;
			}
			if (new_val > 2.5)
				new_val = 2.5;
			
			wins.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 300, scale_x:new_val, scale_y:new_val);
		}
		
	}
	
}
