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
	public class Notification : Actor
	{
		public static const int WIDTH = 300;
		public static const int ICON_SIZE = 48;
		public static const int MARGIN = 12;

		const int SPACING = 6;
		const int PADDING = 4;

		public uint32 id { get; construct; }
		public string summary { get; construct set; }
		public string body { get; construct set; }
		public Gdk.Pixbuf? icon { get; construct set; }
		public NotificationUrgency urgency { get; construct; }
		public int32 expire_timeout { get; construct set; }
		public Window? window { get; construct; }
		public string[] notification_actions { get; construct set; }

		public uint64 relevancy_time { get; private set; }
		public bool being_destroyed { get; private set; default = false; }

		Text summary_label;
		Text body_label;
		GtkClutter.Texture icon_texture;
		GtkClutter.Texture close_button;

		uint remove_timeout = 0;

		public Notification (uint32 id, string summary, string body, Gdk.Pixbuf? icon,
			NotificationUrgency urgency, int32 expire_timeout, Window? window, string[] actions)
		{
			Object (
				id: id,
				summary: summary,
				body: body,
				icon: icon,
				urgency: urgency,
				expire_timeout: expire_timeout,
				window: window,
				notification_actions: actions
			);

			relevancy_time = new DateTime.now_local ().to_unix ();
			width = WIDTH + MARGIN * 2;
			reactive = true;

			set_easing_duration (300);
			set_easing_mode (AnimationMode.EASE_OUT_QUAD);

			summary_label = new Text.with_text (null, "");
			summary_label.line_wrap = true;
			summary_label.use_markup = true;
			summary_label.line_wrap_mode = Pango.WrapMode.WORD_CHAR;

			body_label = new Text.with_text (null, "");
			body_label.line_wrap = true;
			body_label.use_markup = true;
			body_label.line_wrap_mode = Pango.WrapMode.WORD_CHAR;

			icon_texture = new GtkClutter.Texture ();

			// TODO replace with the real close button once multitaskingview is merged
			// close_button = Utils.create_close_button ();
			close_button = new GtkClutter.Texture ();
			try {
				close_button.set_from_pixbuf (Granite.Widgets.Utils.get_close_pixbuf ());
			} catch (Error e) {
				close_button.background_color = { 180, 0, 0, 255 };
			}
			close_button.width = 28;
			close_button.height = 28;
			close_button.opacity = 0;
			close_button.reactive = true;
			close_button.set_easing_duration (300);

			add_child (summary_label);
			add_child (body_label);
			add_child (icon_texture);
			add_child (close_button);

			var canvas = new Canvas ();
			canvas.draw.connect (draw);
			content = canvas;

			set_values ();

			var transition = new TransitionGroup ();
			transition.duration = 400;
			transition.remove_on_complete = true;

			var opacity_transition = new PropertyTransition ("opacity");
			opacity_transition.set_from_value (0);
			opacity_transition.set_to_value (255);

			var slide_transition = new PropertyTransition ("y");
			slide_transition.set_from_value (-60);
			slide_transition.set_to_value (0);
			slide_transition.progress_mode = urgency == NotificationUrgency.LOW ?
				AnimationMode.EASE_OUT_CUBIC : AnimationMode.EASE_OUT_BOUNCE;

			transition.add_transition (opacity_transition);
			transition.add_transition (slide_transition);

			add_transition ("entry", transition);
		}

		public void close ()
		{
			opacity = 0;

			being_destroyed = true;
			get_transition ("opacity").completed.connect (() => destroy ());
		}

		public void update (string summary, string body, Gdk.Pixbuf? icon, int32 expire_timeout,
			string[] actions)
		{
			var visible_change = this.summary != summary || this.body != body;

			this.summary = summary;
			this.body = body;
			this.icon = icon;
			this.expire_timeout = expire_timeout;
			this.relevancy_time = new DateTime.now_local ().to_unix ();

			set_values ();

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

			if (icon != null) {
				try {
					icon_texture.set_from_pixbuf (icon);
				} catch (Error e) {}
			}

			set_timeout ();
		}

		void set_timeout ()
		{
			// crtitical notifications have to be dismissed manually
			if (urgency == NotificationUrgency.CRITICAL)
				return;

			clear_timeout ();

			remove_timeout = Timeout.add (expire_timeout, () => {
				close ();
				remove_timeout = 0;
				return false;
			});
		}

		void clear_timeout ()
		{
			if (remove_timeout != 0) {
				Source.remove (remove_timeout);
				remove_timeout = 0;
			}
		}

		public override bool enter_event (CrossingEvent event)
		{
			close_button.opacity = 255;

			clear_timeout ();

			return true;
		}

		public override bool leave_event (CrossingEvent event)
		{
			close_button.opacity = 0;

			// TODO consider decreasing the timeout now or calculating the remaining
			set_timeout ();

			return true;
		}

		public override void allocate (ActorBox box, AllocationFlags flags)
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

			var icon_alloc = ActorBox ();
			icon_alloc.set_origin (MARGIN + PADDING, MARGIN + PADDING);
			icon_alloc.set_size (ICON_SIZE, ICON_SIZE);
			icon_texture.allocate (icon_alloc, flags);

			var summary_alloc = ActorBox ();
			summary_alloc.set_origin (label_x, label_y);
			summary_alloc.set_size (label_width, summary_height);
			summary_label.allocate (summary_alloc, flags);

			var body_alloc = ActorBox ();
			body_alloc.set_origin (label_x, label_y + summary_height + SPACING);
			body_alloc.set_size (label_width, body_height);
			body_label.allocate (body_alloc, flags);

			var close_alloc = ActorBox ();
			close_alloc.set_origin (MARGIN + PADDING - close_button.width / 2,
				MARGIN + PADDING - close_button.height / 2);
			close_alloc.set_size (close_button.width, close_button.height);
			close_button.allocate (close_alloc, flags);

			var close_click = new ClickAction ();
			close_click.clicked.connect (close);
			close_button.add_action (close_click);

			var content_height = label_height < ICON_SIZE ? ICON_SIZE : label_height;
			box.set_size (MARGIN * 2 + WIDTH, (MARGIN + PADDING) * 2 + content_height);

			base.allocate (box, flags);

			var canvas = (Canvas) content;
			var canvas_width = (int) box.get_width ();
			var canvas_height = (int) box.get_height ();
			if (canvas.width != canvas_width || canvas_height != canvas_height)
				canvas.set_size (canvas_width, canvas_height);
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

		bool draw (Cairo.Context canvas_cr)
		{
			var canvas = (Canvas) content;

			var x = MARGIN;
			var y = MARGIN;
			var width = canvas.width - MARGIN * 2;
			var height = canvas.height - MARGIN * 2;

			var buffer = new Granite.Drawing.BufferSurface (canvas.width, canvas.height);
			var cr = buffer.context;
			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x, y, width, height, 5);

			cr.set_source_rgba (0, 0, 0, 0.6);
			cr.fill_preserve ();
			buffer.exponential_blur (6);

			cr.set_source_rgba (0, 0, 0, 0.1);
			cr.set_line_width (1);
			cr.stroke ();

			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x + 1, y + 1, width - 2, height - 2, 5);
			cr.set_source_rgb (0.945, 0.945, 0.945);
			cr.fill_preserve ();

			var gradient = new Cairo.Pattern.linear (0, 0, 0, height - 2);
			gradient.add_color_stop_rgba (0, 1, 1, 1, 1.0);
			gradient.add_color_stop_rgba (1, 1, 1, 1, 0.6);

			cr.set_source (gradient);
			cr.stroke ();

			canvas_cr.set_operator (Cairo.Operator.CLEAR);
			canvas_cr.paint ();
			canvas_cr.set_operator (Cairo.Operator.OVER);

			canvas_cr.set_source_surface (buffer.surface, 0, 0);
			canvas_cr.paint ();

			return false;
		}
	}
}
