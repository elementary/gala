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

		public Screen screen { get; construct; }

        private Gee.ArrayList<unowned WindowActor> notifications;

		public NotificationStack (Screen screen)
		{
			Object (screen: screen);
		}

		construct
		{
            notifications = new Gee.ArrayList<WindowActor> ();

            screen.monitors_changed.connect (update_stack_allocation);
            screen.workareas_changed.connect (update_stack_allocation);
			update_stack_allocation ();
		}

		public void show_notification (WindowActor notification)
		{
            notification.set_pivot_point (0.5f, 0.5f);

            //  var close_button = Utils.create_close_button ();
			//  close_button.opacity = 0;
			//  close_button.reactive = true;
			//  close_button.set_easing_duration (300);

			//  var close_click = new ClickAction ();
			//  close_click.clicked.connect (() => {
            //      notification.destroy ();
            //  });

            //  close_button.add_action (close_click);
            //  notification.insert_child_above (close_button, null);


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

            /**
             * We will make space for the incomming notification
             * by shifting all current notifications by height
             * and then add it to the notifications list.
             */            
            update_positions (notification.height);

            move_window (notification, stack_x, stack_y + TOP_OFFSET + ADDITIONAL_MARGIN * scale);
            notifications.insert (0, notification);
		}

        void update_stack_allocation ()
        {
			var primary = screen.get_primary_monitor ();
			var area = screen.get_active_workspace ().get_work_area_for_monitor (primary);

			var scale = Utils.get_ui_scaling_factor ();
            stack_width = (WIDTH + MARGIN) * scale;

            stack_x = area.x + area.width - stack_width;
            stack_y = area.y;
        }

		void update_positions (float add_y = 0.0f)
		{
			var scale = Utils.get_ui_scaling_factor ();
            var y = stack_y + TOP_OFFSET + add_y + ADDITIONAL_MARGIN * scale;
			var i = notifications.size;
            var delay_step = i > 0 ? 150 / i : 0;
			foreach (var actor in notifications) {
				actor.save_easing_state ();
				actor.set_easing_mode (AnimationMode.EASE_OUT_BACK);
				actor.set_easing_duration (200);
				actor.set_easing_delay ((i--) * delay_step);

                move_window (actor, -1, (int)y);
                actor.restore_easing_state ();

                y += actor.height;
			}
        }
        
        public void destroy_notification (WindowActor notification)
        {
            notification.save_easing_state ();
			notification.set_easing_duration (100);
			notification.set_easing_mode (AnimationMode.EASE_IN_QUAD);
			notification.opacity = 0;

            notification.x += stack_width;
            notification.restore_easing_state ();

            notifications.remove (notification);
            update_positions ();
        }

        /**
         * This function takes care of properly updating both the actor
         * position and the actual window position.
         * 
         * To enable animations for a window we first need to move it's frame
         * in the compositor and then calculate & apply the coordinates for the window
         * actor.
         */
        static void move_window (Meta.WindowActor actor, int x, int y) {
            unowned Meta.Window window = actor.get_meta_window ();
            var rect = window.get_frame_rect ();
                        
            window.move_frame (false, x != -1 ? x : rect.x, y != -1 ? y : rect.y);

            /**
             * move_frame does not guarantee that the frame rectangle
             * will be updated instantly, get the buffer rectangle.
             */
            rect = window.get_buffer_rect ();
            actor.x = rect.x - ((actor.width - rect.width) / 2);
            actor.y = rect.y - ((actor.height - rect.height) / 2);
        }
	}
}

