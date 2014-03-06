//  
//  Copyright (C) 2012 - 2014 Tom Beckmann, Jacob Parker
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
	[DBus (name="org.pantheon.gala")]
	public class DBus
	{
		static DBus? instance;
		static Plugin plugin;
		
		[DBus (visibile = false)]
		public static void init (Plugin _plugin)
		{
			plugin = _plugin;
			
			Bus.own_name (BusType.SESSION, "org.pantheon.gala", BusNameOwnerFlags.NONE,
				(connection) => {
					if (instance == null)
						instance = new DBus ();
					
					try {
						connection.register_object ("/org/pantheon/gala", instance);
					} catch (Error e) { warning (e.message); }
				},
				() => {},
				() => warning ("Could not acquire name\n") );
		}
		
		private DBus ()
		{
#if HAS_MUTTER38
			if (plugin.background_group != null)
				(plugin.background_group as BackgroundManager).changed.connect (() => background_changed);
			else
				assert_not_reached ();
#endif
		}
		
		public void perform_action (ActionType type)
		{
			plugin.perform_action (type);
		}

#if HAS_MUTTER38
		const double MIN_ALPHA = 0.7;
		const int MIN_VARIANCE = 50;
		const int MIN_LUM = 25;

		class DummyOffscreenEffect : Clutter.OffscreenEffect {
			public signal void done_painting ();
			public override void post_paint ()
			{
				base.post_paint ();
				done_painting ();
			}
		}

		public struct MeanColorInformation
		{
			double mean;
			double variance;
		}

		/**
		 * Emitted when the background change occured and the transition ended.
		 * You can safely call get_optimal_panel_alpha then. It is not guaranteed
		 * that this signal will be emitted only once per group of changes as often
		 * done by GUIs. The change may not be visible to the user.
		 */
		public signal void background_changed ();

		/**
		 * Attaches a dummy offscreen effect to the background at monitor to get its
		 * isolated color data. Then calculate the mean color value and variance. Both
		 * variables are returned as a tuple in that order.
		 *
		 * @param monitor          The monitor where the panel will be placed
		 * @param reference_x      X coordinate of the rectangle used to gather color data
		 *                         relative to the monitor you picked. Values will be clamped
		 *                         to its dimensions
		 * @param reference_y      Y coordinate
		 * @param refenrece_width  Width of the rectangle
		 * @param reference_height Height of the rectangle
		 */
		public async MeanColorInformation get_background_color_information (int monitor,
			int reference_x, int reference_y, int reference_width, int reference_height)
		{
			var background = plugin.background_group.get_child_at_index (monitor);
			if (background == null)
				return { 0, 0 };

			var effect = new DummyOffscreenEffect ();
			background.add_effect (effect);

			var tex_width = (int)background.width;
			var tex_height = (int)background.height;

			int x_start = reference_x;
			int y_start = reference_y;
			int width = int.min (tex_width - reference_x, reference_width);
			int height = int.min (tex_height - reference_y, reference_height);

			if (x_start > tex_width || x_start > tex_height || width <= 0 || height <= 0)
				return { 0, 0 };

			double variance = 0;
			double mean = 0;

			ulong paint_signal_handler = 0;
			paint_signal_handler = effect.done_painting.connect (() => {
				SignalHandler.disconnect (effect, paint_signal_handler);
				background.remove_effect (effect);

				var pixels = new uint8[tex_width * tex_height * 4];
				CoglFixes.texture_get_data ((Cogl.Texture)effect.get_texture (),
					Cogl.PixelFormat.BGRA_8888_PRE, 0, pixels);

				int size = width * height;

				double mean_squares = 0;
				double pixel = 0;

				for (int y = y_start; y < height; y++) {
					for (int x = x_start; x < width; x++) {
						int i = y * width * 4 + x * 4;

						pixel = (0.3 * (double) pixels[i] +
							0.6 * (double) pixels[i + 1] +
							0.11 * (double) pixels[i + 2]) - 128f;

						mean += pixel;
						mean_squares += pixel * pixel;
					}
				}

				mean /= size;
				mean_squares *= mean_squares / size;

				variance = Math.sqrt (mean_squares - mean * mean) / (double) size;

				get_background_color_information.callback ();
			});

			background.queue_redraw ();

			yield;

			return { mean, variance };
		}
#endif
	}
}
