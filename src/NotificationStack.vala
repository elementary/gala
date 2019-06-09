//
//  Copyright (C) 2014 Tom Beckmann
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
	public class NotificationStack : Object
	{
		// we need to keep a small offset to the top, because we clip the container to
		// its allocations and the close button would be off for the first notification
		const int TOP_OFFSET = 2;
		const int ADDITIONAL_MARGIN = 12;
		const int MARGIN = 12;

        const int WIDTH = 300;

        int stack_x;
        int stack_y;
        int stack_width;

		public signal void animations_changed (bool running);

		public Screen screen { get; construct; }

        private Gee.ArrayList<unowned WindowActor> notifications;

		public NotificationStack (Screen screen)
		{
			Object (screen: screen);
		}

		construct
		{
            notifications = new Gee.ArrayList<WindowActor> ();


            
			var scale = Utils.get_ui_scaling_factor ();
            stack_width = (WIDTH + 2 * MARGIN + ADDITIONAL_MARGIN) * scale;
            
            screen.monitors_changed.connect (update_stack_position);
            screen.workareas_changed.connect (update_stack_position);
			update_stack_position ();
			//  var scale = Utils.get_ui_scaling_factor ();
			//  width = (Notification.WIDTH + 2 * Notification.MARGIN + ADDITIONAL_MARGIN) * scale;
			//  clip_to_allocation = true;
		}

		public void show_notification (WindowActor notification)
		{
            notifications.add (notification);
			
            notification.set_pivot_point (0.5f, 0.5f);

			animations_changed (true);
			var scale = Utils.get_ui_scaling_factor ();

            var entry = new TransitionGroup ();
			entry.remove_on_complete = true;
			entry.duration = 400;

			var opacity_transition = new PropertyTransition ("opacity");
			opacity_transition.set_from_value (0);
			opacity_transition.set_to_value (255);

			var flip_transition = new KeyframeTransition ("rotation-angle-x");
			flip_transition.set_from_value (90.0);
			flip_transition.set_to_value (0.0);
			flip_transition.set_key_frames ({ 0.6 });
			flip_transition.set_values ({ -10.0 });

			entry.add_transition (opacity_transition);
			entry.add_transition (flip_transition);
			notification.add_transition ("entry", entry);

			// raise ourselves when we got something to show
			//  get_parent ().set_child_above_sibling (this, null);

			// we have a shoot-over on the start of the close animation, which gets clipped
			// unless we make our container a bit wider and move the notifications over
			notification.margin_left = ADDITIONAL_MARGIN * scale;

			//  notification.destroy.connect (on_notification_destroyed);

			float height;
			notification.get_preferred_height (WIDTH * scale, out height, null);
            update_stack_position ();
			update_positions (height);

            notification.y = stack_y + TOP_OFFSET * scale;
            notification.x = stack_x;
			//  insert_child_at_index (notification, 0);
		}

        void update_stack_position ()
        {
			var primary = screen.get_primary_monitor ();
			var area = screen.get_active_workspace ().get_work_area_for_monitor (primary);

            stack_x = area.x + area.width - stack_width;
            stack_y = area.y;

            //  foreach (var notification in notifications) {
            //      notification.set_translation (area.x + area.width - width, area.y, 0);
            //      //  notification.x = ;
            //      //  notification.y = area.y;
            //  }

        }

		void update_positions (float add_y = 0.0f)
		{
			var scale = Utils.get_ui_scaling_factor ();
			var y = stack_y + add_y + TOP_OFFSET * scale;
			var i = notifications.size;
			var delay_step = i > 0 ? 150 / i : 0;
			foreach (var child in notifications) {
				child.save_easing_state ();
				child.set_easing_mode (AnimationMode.EASE_OUT_BACK);
				child.set_easing_duration (200);
				child.set_easing_delay ((i--) * delay_step);

				child.y = y;
				child.restore_easing_state ();

				y += child.height;
			}
        }
        
        public void destroy_notification (WindowActor notification)
        {
            notification.show();
            notification.save_easing_state ();
			notification.set_easing_duration (100);

			notification.set_easing_mode (AnimationMode.EASE_IN_QUAD);
			notification.opacity = 0;

			//  notification.x = (WIDTH + MARGIN * 2) * Utils.get_ui_scaling_factor ();
            notification.restore_easing_state ();

			//  being_destroyed = true;
			//  var transition = notification.get_transition ("x");
			//  if (notification.transition != null)
            //  notification.transition.completed.connect (() => destroy ());
                
            notifications.remove (notification);
            //  animations_changed (false);
            //  update_positions ();                
			//  else
			//  	destroy ();            
        }
	}
}

