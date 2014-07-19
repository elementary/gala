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

		public ConfirmationNotification (uint32 id, Gdk.Pixbuf? icon, bool icon_only, int progress)
		{
			base (id, icon, NotificationUrgency.LOW, DURATION);

			this.icon_only = icon_only;
			this.has_progress = progress > -1;
			this.progress = progress;
		}

		public override void update_allocation (out float content_height, AllocationFlags flags)
		{
			content_height = ICON_SIZE;
		}

		const int PROGRESS_HEIGHT = 6;

		public override void draw_content (Cairo.Context cr)
		{
			if (!has_progress)
				return;

			var x = MARGIN + PADDING + ICON_SIZE + SPACING;
			var y = MARGIN + PADDING + (ICON_SIZE - PROGRESS_HEIGHT) / 2;
			var width = WIDTH - x - MARGIN;
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

		public void update (Gdk.Pixbuf? icon, int progress)
		{
			this.progress = progress;

			update_base (icon, DURATION);
		}
	}
}
