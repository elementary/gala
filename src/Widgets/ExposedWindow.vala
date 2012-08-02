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

namespace Gala
{
	public class ExposedWindow : Clutter.Group
	{
		public weak Window window;
		Clutter.Clone clone;
		public GtkClutter.Texture icon;
		
		public signal void selected (Window window);
		
		public ExposedWindow (Window _window)
		{
			window = _window;
			
			var actor = _window.get_compositor_private () as WindowActor;
			clone = new Clutter.Clone (actor.get_texture ());
			
			reactive = true;
			
			icon = new GtkClutter.Texture ();
			icon.scale_x = 0.0f;
			icon.scale_y = 0.0f;
			icon.scale_gravity = Clutter.Gravity.CENTER;
			try {
				icon.set_from_pixbuf (Utils.get_icon_for_window (window, 64));
			} catch (Error e) { warning (e.message); }
			
			add_child (clone);
			
			Compositor.get_stage_for_screen (window.get_screen ()).add_child (icon);
		}
		
		public override bool button_press_event (Clutter.ButtonEvent event)
		{
			raise_top ();
			selected (window);
			
			return true;
		}
		
		public void close (bool do_animate=true)
		{
			unowned Rectangle rect = window.get_outer_rect ();
			
			//FIXME need to subtract 10 here to remove jump for most windows, but adds jump for maximized ones
			float delta = (window.maximized_horizontally || window.maximized_vertically)?0:10;
			
			float dest_x = rect.x - delta;
			float dest_y = rect.y - delta;
			
			//stop all running animations
			detach_animation ();
			icon.detach_animation ();
			
			icon.animate (Clutter.AnimationMode.EASE_IN_CUBIC, 100, scale_x:0.0f, scale_y:0.0f)
				.completed.connect ( () => {
				icon.destroy ();
			});
			
			if (do_animate) {
				animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 250, 
					scale_x:1.0f, scale_y:1.0f, x:dest_x, y:dest_y).completed.connect (() => {
					
					(window.get_compositor_private () as Clutter.Actor).show ();
					destroy ();
				});
			} else {
				scale_x = 1.0f;
				scale_y = 1.0f;
				x = dest_x;
				y = dest_y;
				
				(window.get_compositor_private () as Clutter.Actor).show ();
				destroy ();
			}
		}
	}
}
