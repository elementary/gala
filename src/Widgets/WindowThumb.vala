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
	public class WindowThumb : Actor
	{
		public weak Window window;
		Clone clone;
		public GtkClutter.Texture icon;
		public GtkClutter.Texture close_button;
		
		public signal void selected (Window window);
		public signal void closed ();
		
		public WindowThumb (Window _window)
		{
			window = _window;
			
			reactive = true;
			
			var actor = window.get_compositor_private () as WindowActor;
			clone = new Clone (actor);
			
			icon = new GtkClutter.Texture ();
			icon.scale_x = 0.0f;
			icon.scale_y = 0.0f;
			icon.scale_gravity = Gravity.CENTER;
			
			try {
				icon.set_from_pixbuf (Utils.get_icon_for_window (window, 64));
			} catch (Error e) { warning (e.message); }
			
			close_button = new GtkClutter.Texture ();
			close_button.reactive = true;
			close_button.visible = false;
			close_button.scale_x = 0.0f;
			close_button.scale_y = 0.0f;
			close_button.scale_gravity = Gravity.CENTER;
			close_button.button_release_event.connect (close_button_clicked);
			close_button.leave_event.connect ((e) => leave_event (e));
			
			try {
				close_button.set_from_pixbuf (Granite.Widgets.Utils.get_close_pixbuf ());
			} catch (Error e) { warning (e.message); }
			
			add_child (clone);
			
			var stage = Compositor.get_stage_for_screen (window.get_screen ());
			stage.add_child (icon);
			stage.add_child (close_button);
		}
		
		bool close_button_clicked (ButtonEvent event)
		{
			if (event.button != 1)
				return false;
			
			close_window ();
			
			return true;
		}
		
		public void close_window ()
		{
			//make sure we dont see a window closing animation in the background
			clone.source.opacity = 0;
			get_parent ().set_child_below_sibling (this, null);
			closed ();
			destroy ();
			window.delete (window.get_screen ().get_display ().get_current_time ());
		}
		
		public override void destroy ()
		{
			clone.destroy ();
			close_button.destroy ();
			icon.destroy ();
			
			base.destroy ();
		}
		
		public override bool enter_event (CrossingEvent event)
		{
			//if we're still animating don't show the close button
			if (get_animation () != null)
				return false;
			
			close_button.visible = true;
			close_button.animate (AnimationMode.EASE_OUT_ELASTIC, 400, scale_x : 1.0f, scale_y : 1.0f);
			
			return true;
		}
		
		public override bool motion_event (MotionEvent event)
		{
			if (get_animation () != null)
				return false;
			
			close_button.visible = true;
			close_button.animate (AnimationMode.EASE_OUT_ELASTIC, 400, scale_x : 1.0f, scale_y : 1.0f);
			
			return true;
		}
		
		public override bool leave_event (CrossingEvent event)
		{
			if (event.related == close_button)
				return false;
			
			close_button.animate (AnimationMode.EASE_IN_QUAD, 200, scale_x : 0.0f, scale_y : 0.0f)
				.completed.connect (() => close_button.visible = false );
			
			return true;
		}
		
		public override bool button_press_event (ButtonEvent event)
		{
			switch (event.button) {
				case 1:
					get_parent ().set_child_above_sibling (this, null);
					selected (window);
					break;
				case 2:
					close_window ();
					break;
			}
			
			return true;
		}
		
		public void close (bool do_animate = true)
		{
			unowned Meta.Rectangle rect = window.get_outer_rect ();
			
			//FIXME need to subtract 10 here to remove jump for most windows, but adds jump for maximized ones
			float delta = window.maximized_horizontally || window.maximized_vertically ? 0 : 10;
			
			float dest_x = rect.x - delta;
			float dest_y = rect.y - delta;
			
			//stop all running animations
			detach_animation ();
			icon.detach_animation ();
			close_button.detach_animation ();
			
			bool dont_show = window.minimized || window.get_workspace () != window.get_screen ().get_active_workspace ();
			do_animate = do_animate && !dont_show;
			
			if (do_animate) {
				icon.animate (AnimationMode.EASE_IN_CUBIC, 100, scale_x:0.0f, scale_y:0.0f);
				close_button.animate (AnimationMode.EASE_IN_QUAD, 200, scale_x : 0.0f, scale_y : 0.0f);
				
				animate (AnimationMode.EASE_IN_OUT_CUBIC, 300, scale_x:1.0f, scale_y:1.0f, x:dest_x, y:dest_y).completed.connect (() => {
					clone.source.show ();
					destroy ();
				});
			} else {
				if (!dont_show)
					clone.source.show ();
				destroy ();
			}
		}
	}
}
