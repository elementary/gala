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

namespace Gala.Plugins.Notify
{
	public class NotificationStack : Actor
	{
		public signal void animations_changed (bool running);

		public Screen screen { get; construct; }

		int animation_counter = 0;

		public NotificationStack (Screen screen)
		{
			Object (screen: screen);

			width = Notification.WIDTH + 2 * Notification.MARGIN;
		}

		public void show_notification (uint32 id, string summary, string body, Gdk.Pixbuf? icon,
			NotificationUrgency urgency, int32 expire_timeout, uint32 sender_pid, string[] actions)
		{
			if (animation_counter == 0)
				animations_changed (true);

			foreach (var child in get_children ()) {
				var notification = (Notification) child;

				if (notification.id == id && !notification.being_destroyed) {
					notification.update (summary, body, icon, expire_timeout, actions);

					var transition = notification.get_transition ("update");
					if (transition != null) {
						animation_counter++;
						transition.completed.connect (() => {
							if (--animation_counter == 0)
								animations_changed (false);
						});
					}

					return;
				}
			}

			var notification = new Notification (screen, id, summary, body, icon,
				urgency, expire_timeout, sender_pid, actions);

			float height;
			notification.get_preferred_height (Notification.WIDTH, out height, null);
			//update_positions (height);

			insert_child_at_index (notification, 0);

			animation_counter++;

			notification.get_transition ("entry").completed.connect (() => {
				if (--animation_counter == 0)
					animations_changed (false);
			});
		}

		void update_positions (float add_y = 0.0f)
		{
			var y = add_y;
			var i = get_n_children ();
			var delay_step = i > 0 ? 150 / i : 0;
			foreach (var child in get_children ()) {
				if (((Notification) child).being_destroyed)
					continue;

				child.save_easing_state ();
				child.set_easing_mode (AnimationMode.EASE_OUT_BACK);
				child.set_easing_duration (200);
				child.set_easing_delay ((i--) * delay_step);

				child.y = y;
				child.restore_easing_state ();

				y += child.height;
			}
		}
	}
}

