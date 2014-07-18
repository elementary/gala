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
	public class NormalNotification : Notification
	{
		public string summary { get; private set; }
		public string body { get; private set; }
		public uint32 sender_pid { get; private set; }
		public string[] notification_actions { get; private set; }
		public Screen screen { get; private set; }

		Text summary_label;
		Text body_label;

		public NormalNotification (Screen screen, uint32 id, string summary, string body, Gdk.Pixbuf? icon,
			NotificationUrgency urgency, int32 expire_timeout, uint32 pid, string[] actions)
		{
			base (id, icon, urgency, expire_timeout);

			this.screen = screen;
			this.summary = summary;
			this.body = body;
			this.sender_pid = pid;
			this.notification_actions = actions;

			summary_label = new Text.with_text (null, "");
			summary_label.line_wrap = true;
			summary_label.use_markup = true;
			summary_label.line_wrap_mode = Pango.WrapMode.WORD_CHAR;

			body_label = new Text.with_text (null, "");
			body_label.line_wrap = true;
			body_label.use_markup = true;
			body_label.line_wrap_mode = Pango.WrapMode.WORD_CHAR;

			add_child (summary_label);
			add_child (body_label);

			set_values ();
		}

		public void update (string summary, string body, Gdk.Pixbuf? icon, int32 expire_timeout,
			string[] actions)
		{
			var visible_change = this.summary != summary || this.body != body;

			this.summary = summary;
			this.body = body;

			set_values ();
			update_base (icon, expire_timeout);

			if (!visible_change)
				return;

			if (get_transition ("update") != null)
				remove_transition ("update");

			var opacity_transition = new PropertyTransition ("opacity");
			opacity_transition.set_from_value (255);
			opacity_transition.set_to_value (0);
			opacity_transition.duration = 400;
			opacity_transition.auto_reverse = true;
			opacity_transition.repeat_count = 1;
			opacity_transition.remove_on_complete = true;

			add_transition ("update", opacity_transition);
		}

		void set_values ()
		{
			summary_label.set_markup ("<b>" + summary + "</b>");
			body_label.set_markup (body);
		}

		public override void update_allocation (out float content_height, AllocationFlags flags)
		{
			var label_x = MARGIN + PADDING + ICON_SIZE + SPACING;
			var label_width = WIDTH - label_x - MARGIN - SPACING;

			float summary_height, body_height;
			summary_label.get_preferred_height (label_width, null, out summary_height);
			body_label.get_preferred_height (label_width, null, out body_height);

			var label_height = summary_height + SPACING + body_height;
			var label_y = MARGIN + PADDING;
			// center
			if (label_height < ICON_SIZE)
				label_y += (ICON_SIZE - (int) label_height) / 2;

			var summary_alloc = ActorBox ();
			summary_alloc.set_origin (label_x, label_y);
			summary_alloc.set_size (label_width, summary_height);
			summary_label.allocate (summary_alloc, flags);

			var body_alloc = ActorBox ();
			body_alloc.set_origin (label_x, label_y + summary_height + SPACING);
			body_alloc.set_size (label_width, body_height);
			body_label.allocate (body_alloc, flags);

			content_height = label_height < ICON_SIZE ? ICON_SIZE : label_height;
		}

		public override void get_preferred_height (float for_width, out float min_height, out float nat_height)
		{
			var label_x = MARGIN + PADDING + ICON_SIZE + SPACING;
			var label_width = WIDTH - label_x - MARGIN - SPACING;

			float summary_height, body_height;
			summary_label.get_preferred_height (label_width, null, out summary_height);
			body_label.get_preferred_height (label_width, null, out body_height);

			var label_height = summary_height + SPACING + body_height;
			var content_height = label_height < ICON_SIZE ? ICON_SIZE : label_height;

			min_height = nat_height = content_height + (MARGIN + SPACING) * 2;
		}

		public override void activate ()
		{
			var window = get_window ();
			if (window != null) {
				var workspace = window.get_workspace ();
				var time = screen.get_display ().get_current_time ();

				if (workspace != screen.get_active_workspace ())
					workspace.activate_with_focus (window, time);
				else
					window.activate (time);
			}
		}

		Window? get_window ()
		{
			if (sender_pid == 0)
				return null;

			foreach (var actor in Compositor.get_window_actors (screen)) {
				var window = actor.get_meta_window ();

				// the windows are sorted by stacking order when returned
				// from meta_get_window_actors, so we can just pick the first
				// one we find and have a pretty good match
				if (window.get_pid () == sender_pid)
					return window;
			}

			return null;
		}
	}
}

