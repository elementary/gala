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
	public class ConfirmationNotification : Notification
	{
		const int DURATION = 2000;
		const int PROGRESS_HEIGHT = 6;

		public bool has_progress { get; private set; }

		int _progress;
		public int progress {
			get {
				return _progress;
			}
			private set {
				_progress = value;
				content.invalidate ();
			}
		}

		public string confirmation_type { get; private set; }

		// temporary things needed for the slide transition
		GtkClutter.Texture old_texture;
		int old_progress;
		bool transitioning = false;
		float _animation_y_offset = 0.0f;
		public float animation_y_offset {
			get {
				return _animation_y_offset;
			}
			set {
				_animation_y_offset = value;

				var icon_pos = MARGIN + PADDING;
				var height = ICON_SIZE + PADDING * 2;

				icon_texture.y = -height + _animation_y_offset;
				old_texture.y = _animation_y_offset;

				content.invalidate ();
			}
		}


		public ConfirmationNotification (uint32 id, Gdk.Pixbuf? icon, bool icon_only,
			int progress, string confirmation_type)
		{
			Object (id: id, icon: icon, urgency: NotificationUrgency.LOW, expire_timeout: DURATION);

			this.icon_only = icon_only;
			this.has_progress = progress > -1;
			this.progress = progress;
			this.confirmation_type = confirmation_type;
		}

		public override void update_allocation (out float content_height, AllocationFlags flags)
		{
			content_height = ICON_SIZE;
		}

		public override void draw_content (Cairo.Context cr)
		{
			if (!has_progress)
				return;

			var x = MARGIN + PADDING + ICON_SIZE + SPACING;
			var y = MARGIN + PADDING + (ICON_SIZE - PROGRESS_HEIGHT) / 2;
			var width = WIDTH - x - MARGIN;

			if (!transitioning)
				draw_progress_bar (cr, x, y, width, progress);
			else {
				Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, MARGIN, MARGIN, WIDTH - MARGIN * 2, ICON_SIZE + PADDING * 2, 4);
				cr.clip ();

				var height_offset = ICON_SIZE + PADDING * 2;

				draw_progress_bar (cr, x, y + animation_y_offset, width, old_progress);
				draw_progress_bar (cr, x, y + animation_y_offset - height_offset, width, progress);

				cr.reset_clip ();
			}
		}

		void draw_progress_bar (Cairo.Context cr, int x, float y, int width, int progress)
		{
			var fraction = (int) Math.floor (progress.clamp (0, 100) / 100.0 * width);

			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x, y, width,
				PROGRESS_HEIGHT, PROGRESS_HEIGHT / 2);
			cr.set_source_rgb (0.8, 0.8, 0.8);
			cr.fill ();

			if (progress > 0) {
				Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x, y, fraction,
					PROGRESS_HEIGHT, PROGRESS_HEIGHT / 2);
				cr.set_source_rgb (0.3, 0.3, 0.3);
				cr.fill ();
			}
		}

		public void update (Gdk.Pixbuf? icon, int progress, string confirmation_type,
			bool icon_only, bool has_progress)
		{
			if (this.confirmation_type != confirmation_type) {
				this.confirmation_type = confirmation_type;

				Transition transition;
				if ((transition = get_transition ("switch")) != null) {
					transition.completed ();
					remove_transition ("switch");
				}

				old_progress = this.progress;
				old_texture = new GtkClutter.Texture ();
				icon_container.add_child (old_texture);
				icon_container.set_clip (0, -PADDING, ICON_SIZE, ICON_SIZE + PADDING * 2);

				try {
					old_texture.set_from_pixbuf (this.icon);
				} catch (Error e) {}

				transition = new PropertyTransition ("animation-y-offset");
				transition.duration = 200;
				transition.progress_mode = AnimationMode.EASE_IN_OUT_QUAD;
				transition.set_from_value (0.0f);
				transition.set_to_value (ICON_SIZE + PADDING * 2.0f);
				transition.remove_on_complete = true;

				transition.completed.connect (() => {
					old_texture.destroy ();
					icon_container.remove_clip ();
					_animation_y_offset = 0;
					transitioning = false;
				});

				add_transition ("switch", transition);
				transitioning = true;
			}

			if (this.icon_only != icon_only) {
				this.icon_only = icon_only;
				queue_relayout ();
			}

			this.has_progress = has_progress;
			this.progress = progress;

			update_base (icon, DURATION);
		}
	}
}
