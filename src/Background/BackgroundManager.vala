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
	public class BackgroundManager : Object
	{
		const string BACKGROUND_SCHEMA = "org.gnome.desktop.background";
		const uint FADE_ANIMATION_TIME = 1000;

		public Meta.BackgroundEffects effects { get; construct set; }
		public int monitor_index { get; construct set; }
		public bool control_position { get; construct set; }

		public Settings settings { get; construct set; }
		public Meta.Screen screen { get; construct set; }

		public Clutter.Actor container { get; construct set; }
		public Background background { get; private set; }
		Background? new_background = null;

		public signal void changed ();

		public BackgroundManager (Meta.Screen screen, Clutter.Actor container, int monitor_index,
			Meta.BackgroundEffects effects, bool control_position, string settings_schema = BACKGROUND_SCHEMA)
		{
			Object (settings: new Settings (settings_schema), 
				container: container,
				effects: effects,
				monitor_index: monitor_index,
				screen: screen,
				control_position: control_position);

			background = create_background ();
		}

		public void destroy ()
		{
			if (new_background != null) {
				new_background.actor.destroy();
				new_background = null;
			}

			if (background != null) {
				background.actor.destroy();
				background = null;
			}
		}

		public void update_background (Background background, int monitor_index) {
			var new_background = create_background ();
			new_background.vignette_sharpness = background.vignette_sharpness;
			new_background.brightness = background.brightness;
			new_background.actor.visible = background.actor.visible;

			new_background.loaded_signal_id = new_background.loaded.connect (() => {
				new_background.disconnect (new_background.loaded_signal_id);
				new_background.loaded_signal_id = 0;
				background.actor.animate(Clutter.AnimationMode.EASE_OUT_QUAD, FADE_ANIMATION_TIME,
					opacity : 0).completed.connect (() => {
						if (this.new_background == new_background) {
							this.background = new_background;
							this.new_background = null;
						} else {
							new_background.actor.destroy ();
						}

						background.actor.destroy ();

						changed ();
				});
			});

			this.new_background = new_background;
		}

		public Background create_background ()
		{
			var background = new Background (monitor_index, effects, settings);
			container.add_child (background.actor);

			var monitor = screen.get_monitor_geometry (monitor_index);
			background.actor.set_size(monitor.width, monitor.height);
			if (control_position) {
				background.actor.set_position (monitor.x, monitor.y);
				background.actor.lower_bottom ();
			}

			background.change_signal_id = background.changed.connect (() => {
				background.disconnect (background.change_signal_id);
				update_background (background, monitor_index);
				background.change_signal_id = 0;
			});

			background.actor.destroy.connect (() => {
				if (background.change_signal_id != 0)
					background.disconnect (background.change_signal_id);

				if (background.loaded_signal_id != 0)
					background.disconnect (background.loaded_signal_id);
			});

			return background;
		}
	}
}

