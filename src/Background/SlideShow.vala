//
//  Copyright (C) 2013 Tom Beckmann, Rico Tzschichholz
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

namespace Gala
{
	public class SlideShow : Meta.BackgroundGroup
	{
		const double ANIMATION_OPACITY_STEP_INCREMENT = 4.0;
		const double ANIMATION_MIN_WAKEUP_INTERVAL = 1.0;

		public string file { get; construct set; }
		public Meta.Screen screen { get; construct set; }
		public int monitor { get; construct set; }
		public GDesktop.BackgroundStyle style { get; construct set; }

		Gnome.BGSlideShow? animation = null;

		double animation_duration = 0.0;
		double animation_progress = 0.0;

		uint update_animation_timeout_id;

		Meta.BackgroundActor image_from;
		Meta.BackgroundActor image_to;

		public SlideShow (string file, Meta.Screen screen, int monitor, GDesktop.BackgroundStyle style)
		{
			Object (file: file, screen: screen, monitor: monitor, style: style);
		}

		construct
		{
			var geom = screen.get_monitor_geometry (monitor);
			width = geom.width;
			height = geom.height;

			image_to = new Meta.BackgroundActor ();
			image_from = new Meta.BackgroundActor ();

			add_child (image_from);
			add_child (image_to);
		}

		~SlideShow ()
		{
			if (update_animation_timeout_id > 0)
				Source.remove (update_animation_timeout_id);
		}

		public async bool load ()
		{
			animation = new Gnome.BGSlideShow (file);
			animation.load_async (null, (obj, res) => {
				load.callback ();
			});
			yield;

			yield update_animation ();

			return true;
		}

		/**
		 * SlideShow animation related functions
		 */
		async void update_animation ()
		{
			if (animation == null)
				return;

			update_animation_timeout_id = 0;

			bool is_fixed;
			string file_from, file_to;
			double progress, duration;
			animation.get_current_slide ((int)width, (int)height, out progress,
				out duration, out is_fixed, out file_from, out file_to);

			animation_duration = duration;
			animation_progress = progress;

			if (file_from == null && file_to == null) {
				queue_update_animation ();
				return;
			}

			if (image_from.content == null
				|| (image_from.content as Meta.Background).get_filename () != file_from) {
				yield update_image (image_from, file_from);
			}
			if (image_to.content == null
				|| (image_to.content as Meta.Background).get_filename () != file_to) {
				yield update_image (image_to, file_to);
			}

			update_animation_progress ();
		}

		/**
		 * Returns the passed orig_image with the correct content or a new one if orig_image was null
		 */
		async void update_image (Meta.BackgroundActor image, string? file)
		{
			if (file == null) {
				image.visible = false;
				return;
			}

			image.visible = true;
			image.content = yield BackgroundCache.get_default ().load_image (file, monitor, style);
		}

		void queue_update_animation ()
		{
			if (update_animation_timeout_id != 0 || animation_duration == 0.0)
				return;

			var n_steps = 255 / ANIMATION_OPACITY_STEP_INCREMENT;
			var time_per_step = (uint)((animation_duration * 1000) / n_steps);
			var interval = uint.max ((uint)(ANIMATION_MIN_WAKEUP_INTERVAL * 1000), time_per_step);

			if (interval > uint.MAX)
				return;

			update_animation_timeout_id = Clutter.Threads.Timeout.add (interval, () => {
				update_animation_timeout_id = 0;
				update_animation.begin ();
				return false;
			});
		}

		void update_animation_progress ()
		{
			if (image_to != null)
				image_to.opacity = (uint)(animation_progress * 255);

			queue_update_animation ();
		}
	}
}

