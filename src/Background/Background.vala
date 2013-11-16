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
	/**
	 * Group that holds a pattern at the very bottom and then an image showing the
	 * current wallpaper above (and one more additional image for transitions).
	 * It listens to changes on the provided settings object and updates accordingly.
	 */
	public class Background : Meta.BackgroundGroup
	{
		Meta.BackgroundActor pattern;
		Meta.BackgroundActor? image = null;

		const uint ANIMATION_TRANSITION_DURATION = 1500;

		public Meta.Screen screen { get; construct set; }
		public int monitor { get; construct set; }
		public Settings settings { get; construct set; }

		Gnome.BGSlideShow? animation = null;
		Meta.BackgroundActor? second_image = null;
		double animation_duration = 0.0;
		double animation_progress = 0.0;
		uint update_animation_timeout_id;
		const double ANIMATION_OPACITY_STEP_INCREMENT = 4.0;
		const double ANIMATION_MIN_WAKEUP_INTERVAL = 1.0;

		public Background (Meta.Screen screen, int monitor, Settings settings)
		{
			Object (screen: screen, monitor: monitor, settings: settings);

			pattern = new Meta.BackgroundActor ();
			pattern.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.ALL, 0));
			add_child (pattern);

			load (null);

			settings.changed.connect (load);
		}

		/**
		 * (Re)loads all components if key_changed is null or only the key_changed component
		 */
		void load (string? key_changed)
		{
			var all = key_changed == null;
			var cache = BackgroundCache.get_default ();

			// update images
			if (all || key_changed == "picture-uri" || key_changed == "picture-options") {
				var file = File.new_for_commandline_arg (settings.get_string ("picture-uri")).get_path ();
				var style = style_string_to_enum (settings.get_string ("picture-options"));

				// no image at all
				if (style == GDesktop.BackgroundStyle.NONE) {
					if (image != null) {
						image.destroy ();
						image = null;
					}
					if (second_image != null) {
						second_image.destroy ();
						second_image = null;
					}
					animation = null;
				// animation
				} else if (file.has_suffix (".xml")) {
					animation = new Gnome.BGSlideShow (file);
					try {
						if (animation.load ()) {
							update_animation ();
						}
					} catch (Error e) {
						warning (e.message);
					}
				// normal wallpaper
				} else {
					animation = null;
					if (second_image != null) {
						second_image.destroy ();
						second_image = null;
					}
					cache.load_image.begin (file, monitor, style, (obj, res) => {
						var content = cache.load_image.end (res);
						if (content != null) {
							set_image (content);
						// if loading failed, destroy our image and show the pattern
						} else if (image != null) {
							image.destroy ();
							image = null;
						}
					});
				}
			}

			// update image opacity
			if (all || key_changed == "picture-opacity") {
				if (image != null)
					image.opacity = (uint8)(settings.get_int ("picture-opacity") / 100.0 * 255);
			}

			// update pattern
			if (all
				|| key_changed == "primary-color"
				|| key_changed == "secondary-color"
				|| key_changed == "color-shading-type") {
				var primary_color = Clutter.Color.from_string (settings.get_string ("primary-color"));
				var secondary_color = Clutter.Color.from_string (settings.get_string ("secondary-color"));
				var shading_type = shading_string_to_enum (settings.get_string ("color-shading-type"));
				pattern.content = cache.load_pattern (monitor, primary_color, secondary_color, shading_type);
			}
		}

		void set_image (Meta.Background content)
		{
			var new_image = new Meta.BackgroundActor ();
			new_image.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.ALL, 0));
			new_image.content = content;
			new_image.opacity = 0;

			insert_child_above (new_image, null);

			var dest_opacity = (uint8)(settings.get_int ("picture-opacity") / 100.0 * 255);
			new_image.animate (Clutter.AnimationMode.EASE_OUT_QUAD, ANIMATION_TRANSITION_DURATION,
				opacity: dest_opacity).completed.connect (() => {
				if (image != null)
					image.destroy ();
				image = new_image;
			});
		}

		/**
		 *  translates the string returned from gsettings for the color-shading-type key to the
		 *  appropriate GDesktop.BackgroundShading enum value
		 */
		GDesktop.BackgroundShading shading_string_to_enum (string shading)
		{
			switch (shading) {
				case "horizontal":
					return GDesktop.BackgroundShading.HORIZONTAL;
				case "vertical":
					return GDesktop.BackgroundShading.VERTICAL;
			}

			return GDesktop.BackgroundShading.SOLID;
		}

		/**
		 *  translates the string returned from gsettings for the picture-options key to the
		 *  appropriate GDesktop.BackgroundStyle enum value
		 */
		GDesktop.BackgroundStyle style_string_to_enum (string style)
		{
			switch (style) {
				case "wallpaper":
					return GDesktop.BackgroundStyle.WALLPAPER;
				case "centered":
					return GDesktop.BackgroundStyle.CENTERED;
				case "scaled":
					return GDesktop.BackgroundStyle.SCALED;
				case "stretched":
					return GDesktop.BackgroundStyle.STRETCHED;
				case "zoom":
					return GDesktop.BackgroundStyle.ZOOM;
				case "spanned":
					return GDesktop.BackgroundStyle.SPANNED;
			}

			return GDesktop.BackgroundStyle.NONE;
		}

		/**
		 * SlideShow animation related functions
		 */
		void update_animation ()
		{
			if (animation == null)
				return;

			update_animation_timeout_id = 0;

			var geom = screen.get_monitor_geometry (monitor);

			bool is_fixed;
			string file_from, file_to;
			double progress, duration;
			animation.get_current_slide (geom.width, geom.height, out progress,
				out duration, out is_fixed, out file_from, out file_to);

			animation_duration = duration;
			animation_progress = progress;

			print ("Animation Update\nfrom: %s to: %s, progress: %f, duration: %f\n", file_from, file_to, progress, duration);
			if (file_from == null && file_to == null) {
				queue_update_animation ();
				return;
			}

			if (image == null || image.content == null
				|| (image.content as Meta.Background).get_filename () != file_from) {
				image = update_image (image, file_from, false);
			}
			if (second_image == null || second_image.content == null
				|| (second_image.content as Meta.Background).get_filename () != file_to) {
				second_image = update_image (second_image, file_to, true);
			}

			update_animation_progress ();
		}

		/**
		 * Returns the passed orig_image with the correct content or a new one if orig_image was null
		 */
		Meta.BackgroundActor? update_image (Meta.BackgroundActor? orig_image, string? file, bool topmost)
		{
			Meta.BackgroundActor image = null;

			if (orig_image != null)
				image = orig_image;

			if (file == null) {
				if (image != null) {
					image.destroy ();
					image = null;
				}
				return null;
			}

			if (image == null) {
				image = new Meta.BackgroundActor ();
				image.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.ALL, 0));
				if (topmost)
					insert_child_above (image, null);
				else
					insert_child_above (image, pattern);
			}

			var cache = BackgroundCache.get_default ();
			var style = style_string_to_enum (settings.get_string ("picture-options"));
			cache.load_image.begin (file, monitor, style, (obj, res) => {
				image.content = cache.load_image.end (res);
			});

			return image;
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

			update_animation_timeout_id = Timeout.add (interval, () => {
				update_animation_timeout_id = 0;
				update_animation ();
				return false;
			});
		}

		void update_animation_progress ()
		{
			if (second_image != null)
				second_image.opacity = (uint)(animation_progress * 255);

			queue_update_animation ();
		}
	}
}

