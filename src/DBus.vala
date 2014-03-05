//  
//  Copyright (C) 2012- 2014 Tom Beckmann // TODO add Jacob Parker?
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

		/**
		 * Emitted when the background change occured and the transition ended.
		 * You can safely call get_optimal_panel_alpha then. It is not guaranteed
		 * that this signal will be emitted only once per group of changes as often
		 * done by GUIs. The change may not be visible to the user.
		 */
		public signal void background_changed ();

		/**
		 * Attaches a dummy offscreen effect to the background at monitor to get its
		 * isolated color data. Then calculate whether we can savely assign a panel
		 * 0 alpha or use MIN_ALPHA Instead based on the data up to reference_height.
		 *
		 * @param monitor          The monitor where the panel will be placed
		 * @param reference_height The height which will serve as a reference for 
		 *                         gathering color data. You may want to adjust this
		 *                         depending on the panel's height.
		 */
		public async double get_optimal_panel_alpha (int monitor, int reference_height)
		{
			var background = plugin.background_group.get_child_at_index (monitor);
			if (background == null)
				return MIN_ALPHA;

			var effect = new DummyOffscreenEffect ();
			background.add_effect (effect);

			var width = (int)background.width;
			var height = (int)background.height;

			double alpha = 0;

			ulong paint_signal_handler = 0;
			paint_signal_handler = effect.done_painting.connect (() => {
				SignalHandler.disconnect (effect, paint_signal_handler);
				background.remove_effect (effect);

				var pixels = new uint8[width * height * 4];
				((Cogl.Texture)effect.get_texture ()).get_data (Cogl.PixelFormat.BGRA_8888_PRE,
					0, pixels);

				int size = width * reference_height;

				double mean = 0;
				double mean_squares = 0;

				double pixel = 0;
				int imax = size * 4;

				for (int i = 0; i < imax; i += 4) {
					pixel = (0.3 * (double) pixels[i] +
						0.6 * (double) pixels[i + 1] +
						0.11 * (double) pixels[i + 2]) - 128f;

					mean += pixel;
					mean_squares += pixel * pixel;
				}

				mean /= size;
				mean_squares *= mean_squares / size;

				double variance = Math.sqrt(mean_squares - mean * mean) / (double) size;

				if (mean > MIN_LUM || variance > MIN_VARIANCE)
					alpha = MIN_ALPHA;

				get_optimal_panel_alpha.callback ();
			});

			background.queue_redraw ();

			yield;

			return alpha;
		}
#endif
	}
}
