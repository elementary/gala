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
using Meta;

namespace Gala
{
	public class Zooming : Object
	{
		Plugin plugin;
		
		const uint MOUSE_POLL_TIME = 50;
		uint mouse_poll_timer = 0;
		float current_zoom = 1.0f;
		
		public Zooming (Plugin _plugin)
		{
			plugin = _plugin;
		}
		
		~Zooming ()
		{
			if (mouse_poll_timer > 0)
				Source.remove (mouse_poll_timer);
			mouse_poll_timer = 0;
		}
		
		public void zoom_in () {
			zoom (true);
		}
		
		public void zoom_out () {
			zoom (false);
		}
		
		void zoom (bool @in)
		{
			// Nothing to do if zooming out of our bounds is requested
			if (current_zoom <= 1.0f && !@in)
				return;
			else if (current_zoom >= 2.5f && @in)
				return;
			
			var wins = Compositor.get_window_group_for_screen (plugin.get_screen ());
			
			// Add timer to poll current mouse position to reposition window-group
			// to show requested zoomed area
			if (mouse_poll_timer == 0) {
				float mx, my;
				var client_pointer = Gdk.Display.get_default ().get_device_manager ().get_client_pointer ();
				client_pointer.get_position (null, out mx, out my);
				wins.scale_center_x = mx;
				wins.scale_center_y = my;
				
				mouse_poll_timer = Timeout.add (MOUSE_POLL_TIME, () => {
					client_pointer.get_position (null, out mx, out my);
					if (wins.scale_center_x == mx && wins.scale_center_y == my)
						return true;
					
					wins.animate (AnimationMode.LINEAR, MOUSE_POLL_TIME, scale_center_x : mx, scale_center_y : my);
					
					return true;
				});
			}
			
			current_zoom += (@in ? 0.5f : -0.5f);
			
			if (current_zoom <= 1.0f) {
				current_zoom = 1.0f;
				
				if (mouse_poll_timer > 0)
					Source.remove (mouse_poll_timer);
				mouse_poll_timer = 0;
				
				wins.animate (AnimationMode.EASE_OUT_CUBIC, 300, scale_x : 1.0f, scale_y : 1.0f).completed.connect (() => {
					wins.scale_center_x = 0.0f;
					wins.scale_center_y = 0.0f;
				});
				
				return;
			}
			
			wins.animate (AnimationMode.EASE_OUT_CUBIC, 300, scale_x : current_zoom, scale_y : current_zoom);
		}
	}
}
