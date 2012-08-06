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
	
	public class Zooming : Clutter.Actor
	{
		
		Plugin plugin;
		
		public Zooming (Plugin _plugin)
		{
			plugin = _plugin;
			var stage = Compositor.get_stage_for_screen (plugin.get_screen ());
			
			visible = false;
			reactive = true;
			
			add_constraint (new BindConstraint (stage, BindCoordinate.WIDTH, 0));
			add_constraint (new BindConstraint (stage, BindCoordinate.HEIGHT, 0));
			
		}
		
		public override bool key_press_event (Clutter.KeyEvent event)
		{
			switch (event.keyval) {
				case Key.Escape:
					end ();
					
					return true;
				case Key.plus:
				case Key.KP_Add:
					zoom (true);
					
					return true;
				case Key.KP_Subtract:
				case Key.minus:
					zoom (false);
					
					return true;
			}
			
			return false;
		}
		
		public override bool button_release_event (ButtonEvent event)
		{
			end ();
			
			return true;
		}
		
		public override void key_focus_out ()
		{
			end ();
		}
		
		public override bool motion_event (Clutter.MotionEvent event)
		{
			var wins = Compositor.get_window_group_for_screen (plugin.get_screen ());
			wins.scale_center_x = event.x * (1 / (float)scale_x);
			wins.scale_center_y = event.y * (1 / (float)scale_x);
			
			return true;
		}
		
		void end ()
		{
			if (!visible)
				return;
			
			visible = false;
			
			var wins = Compositor.get_window_group_for_screen (plugin.get_screen ());
			wins.animate (AnimationMode.EASE_OUT_CUBIC, 300, scale_x:1.0, scale_y:1.0).completed.connect (() => {
				wins.scale_center_x = 0.0f;
				wins.scale_center_y = 0.0f;
			});
			plugin.end_modal ();
			
			plugin.update_input_area ();
		}
		
		public void zoom (bool in)
		{
			var wins = Compositor.get_window_group_for_screen (plugin.get_screen ());
			
			//setup things
			if (in && !visible) {
				plugin.begin_modal ();
				grab_key_focus ();
				
				int mx, my;
				Gdk.Display.get_default ().get_device_manager ().get_client_pointer ().get_position (null, out mx, out my);
				wins.scale_center_x = mx;
				wins.scale_center_y = my;
				
				visible = true;
				get_parent ().set_child_above_sibling (this, null);
				Utils.set_input_area (plugin.get_screen (), InputArea.FULLSCREEN);
			}
			
			if (!visible)
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
