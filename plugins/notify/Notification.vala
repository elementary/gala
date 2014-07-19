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
	public abstract class Notification : Actor
	{
		public const int WIDTH = 300;
		public const int ICON_SIZE = 48;
		public const int MARGIN = 12;

		public const int SPACING = 6;
		public const int PADDING = 4;

		public uint32 id { get; construct; }
		public Gdk.Pixbuf? icon { get; construct set; }
		public NotificationUrgency urgency { get; construct; }
		public int32 expire_timeout { get; construct set; }

		public uint64 relevancy_time { get; private set; }
		public bool being_destroyed { get; private set; default = false; }

		protected bool icon_only { get; protected set; default = false; }

		GtkClutter.Texture icon_texture;
		GtkClutter.Texture close_button;

		uint remove_timeout = 0;

		public Notification (uint32 id, Gdk.Pixbuf? icon, NotificationUrgency urgency,
			int32 expire_timeout)
		{
			Object (
				id: id,
				icon: icon,
				urgency: urgency,
				expire_timeout: expire_timeout
			);

			relevancy_time = new DateTime.now_local ().to_unix ();
			width = WIDTH + MARGIN * 2;
			reactive = true;
			margin_left = 12;
			set_pivot_point (0.5f, 0.5f);

			icon_texture = new GtkClutter.Texture ();
			icon_texture.set_pivot_point (0.5f, 0.5f);

			close_button = Utils.create_close_button ();
			close_button.opacity = 0;
			close_button.reactive = true;
			close_button.set_easing_duration (300);

			add_child (icon_texture);
			add_child (close_button);

			var canvas = new Canvas ();
			canvas.draw.connect (draw);
			content = canvas;

			set_values ();

			var click = new ClickAction ();
			click.clicked.connect (() => {
				activate ();
			});
			add_action (click);

			open ();
		}

		public void open () {
			var entry = new TransitionGroup ();
			entry.remove_on_complete = true;
			entry.progress_mode = AnimationMode.EASE_IN_OUT_CUBIC;
			entry.duration = 600;

			var opacity_transition = new PropertyTransition ("opacity");
			opacity_transition.set_from_value (0);
			opacity_transition.set_to_value (255);

			var flip_transition = new KeyframeTransition ("rotation-angle-x");
			flip_transition.set_from_value (-90.0);
			flip_transition.set_to_value (0.0);
			flip_transition.set_key_frames ({ 0.6 });
			flip_transition.set_values ({ 10.0 });

			entry.add_transition (opacity_transition);
			entry.add_transition (flip_transition);
			add_transition ("entry", entry);

			switch (urgency) {
				case NotificationUrgency.LOW:
					return;
				case NotificationUrgency.NORMAL:
					var icon_entry = new TransitionGroup ();
					icon_entry.duration = 1000;
					icon_entry.remove_on_complete = true;
					icon_entry.progress_mode = AnimationMode.EASE_IN_OUT_CUBIC;

					var icon_opacity_transition = new KeyframeTransition ("opacity");
					icon_opacity_transition.set_from_value (0);
					icon_opacity_transition.set_to_value (255);
					icon_opacity_transition.set_key_frames ({ 0.1, 0.6 });
					icon_opacity_transition.set_values ({ 0, 255 });

					var scale_x_transition = new KeyframeTransition ("scale-x");
					scale_x_transition.set_from_value (0.0);
					scale_x_transition.set_to_value (1.0);
					scale_x_transition.set_key_frames ({ 0.1, 0.6 });
					scale_x_transition.set_values ({ 0, 1.3 });

					var scale_y_transition = new KeyframeTransition ("scale-y");
					scale_y_transition.set_from_value (0.0);
					scale_y_transition.set_to_value (1.0);
					scale_y_transition.set_key_frames ({ 0.15, 0.6 });
					scale_y_transition.set_values ({ 0, 1.3 });

					icon_entry.add_transition (icon_opacity_transition);
					icon_entry.add_transition (scale_x_transition);
					icon_entry.add_transition (scale_y_transition);

					icon_texture.add_transition ("entry", icon_entry);

					return;
				case NotificationUrgency.CRITICAL:
					var icon_entry = new TransitionGroup ();
					icon_entry.duration = 1000;
					icon_entry.remove_on_complete = true;
					icon_entry.progress_mode = AnimationMode.EASE_IN_OUT_CUBIC;

					double[] keyframes = { 0.2, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0 };
					GLib.Value[] scale = { 0.0, 1.2, 1.6, 1.6, 1.6, 1.6, 1.2, 1.0 };

					var rotate_transition = new KeyframeTransition ("rotation-angle-z");
					rotate_transition.set_from_value (30.0);
					rotate_transition.set_to_value (0.0);
					rotate_transition.set_key_frames (keyframes);
					rotate_transition.set_values ({ 30.0, -30.0, 30.0, -20.0, 10.0, -5.0, 2.0, 0.0 });

					var scale_x_transition = new KeyframeTransition ("scale-x");
					scale_x_transition.set_from_value (0.0);
					scale_x_transition.set_to_value (1.0);
					scale_x_transition.set_key_frames (keyframes);
					scale_x_transition.set_values (scale);

					var scale_y_transition = new KeyframeTransition ("scale-y");
					scale_y_transition.set_from_value (0.0);
					scale_y_transition.set_to_value (1.0);
					scale_y_transition.set_key_frames (keyframes);
					scale_y_transition.set_values (scale);

					icon_entry.add_transition (rotate_transition);
					icon_entry.add_transition (scale_x_transition);
					icon_entry.add_transition (scale_y_transition);

					icon_texture.add_transition ("entry", icon_entry);
					return;
			}
		}

		public void close ()
		{
			set_easing_duration (200);

			set_easing_mode (AnimationMode.EASE_IN_QUAD);
			opacity = 0;

			set_easing_mode (AnimationMode.EASE_IN_BACK);
			x = WIDTH + MARGIN * 2;

			being_destroyed = true;
			var transition = get_transition ("x");
			if (transition != null)
				transition.completed.connect (() => destroy ());
			else
				destroy ();
		}

		public void update_base (Gdk.Pixbuf? icon, int32 expire_timeout)
		{
			this.icon = icon;
			this.expire_timeout = expire_timeout;
			this.relevancy_time = new DateTime.now_local ().to_unix ();

			set_values ();
		}

		void set_values ()
		{
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
			if (expire_timeout == 0 || urgency == NotificationUrgency.CRITICAL)
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

		public virtual void activate ()
		{
		}

		public virtual void draw_content (Cairo.Context cr)
		{
		}

		public abstract void update_allocation (out float content_height, AllocationFlags flags);

		public override void allocate (ActorBox box, AllocationFlags flags)
		{
			var icon_alloc = ActorBox ();

			icon_alloc.set_origin (icon_only ? (WIDTH - ICON_SIZE) / 2 : MARGIN + PADDING, MARGIN + PADDING);
			icon_alloc.set_size (ICON_SIZE, ICON_SIZE);
			icon_texture.allocate (icon_alloc, flags);

			var close_alloc = ActorBox ();
			close_alloc.set_origin (MARGIN + PADDING - close_button.width / 2,
				MARGIN + PADDING - close_button.height / 2);
			close_alloc.set_size (close_button.width, close_button.height);
			close_button.allocate (close_alloc, flags);

			var close_click = new ClickAction ();
			close_click.clicked.connect (close);
			close_button.add_action (close_click);

			float content_height;
			update_allocation (out content_height, flags);
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
			min_height = nat_height = ICON_SIZE + (MARGIN + PADDING) * 2;
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

			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x , y + 3, width, height, 4);
			cr.set_source_rgba (0, 0, 0, 0.3);
			cr.fill ();
			buffer.exponential_blur (6);

			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x - 0.5 , y - 0.5, width + 1, height + 1, 4);
			cr.set_source_rgba (0, 0, 0, 0.3);
			cr.set_line_width (1);
			cr.stroke ();

			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x, y, width, height, 4);
			cr.set_source_rgb (0.945, 0.945, 0.945);
			cr.fill ();

			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x + 0.5, y + 0.5, width - 1, height - 1, 3);
			var gradient = new Cairo.Pattern.linear (0, 0, 0, height - 2);
			gradient.add_color_stop_rgba (0, 1, 1, 1, 1.0);
			gradient.add_color_stop_rgba (1, 1, 1, 1, 0.6);
			cr.set_source (gradient);
			cr.set_line_width (1);
			cr.stroke ();

			// TODO move buffer out and optimize content drawing
			draw_content (cr);

			canvas_cr.set_operator (Cairo.Operator.CLEAR);
			canvas_cr.paint ();
			canvas_cr.set_operator (Cairo.Operator.OVER);

			canvas_cr.set_source_surface (buffer.surface, 0, 0);
			canvas_cr.paint ();

			return false;
		}
	}
}