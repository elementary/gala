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
		const uint ANIMATION_TRANSITION_DURATION = 1500;

		public signal void changed ();

		public Meta.Screen screen { get; construct; }
		public int monitor { get; construct; }
		public Settings settings { get; construct; }

		Meta.BackgroundActor pattern;
		Clutter.Actor? image = null;

		public Background (Meta.Screen screen, int monitor, Settings settings)
		{
			Object (screen: screen, monitor: monitor, settings: settings);
		}

		construct
		{
			pattern = new Meta.BackgroundActor ();
			pattern.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.SIZE, 0));
			add_child (pattern);

			load (null);

			settings.changed.connect (load);
		}

		~Background ()
		{
			settings.changed.disconnect (load);
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
				var style = style_string_to_enum (settings.get_string ("picture-options"));
				var uri = settings.get_string ("picture-uri");

				string filename;
				if (GLib.Uri.parse_scheme (uri) != null)
					filename = File.new_for_uri (uri).get_path ();
				else
					filename = uri;

				// no image at all or malformed picture-uri
				if (filename == null || filename == "" || style == GDesktop.BackgroundStyle.NONE) {
					set_current (null);
				// animation
				} else if (filename.has_suffix (".xml")) {
					var slides = new SlideShow (filename, screen, 0, style);

					slides.load.begin ((obj, res) => {
						if (!slides.load.end (res))
							set_current (null);
						else
							set_current (slides);
					});
				// normal wallpaper
				} else {
					cache.load_image.begin (filename, monitor, style, (obj, res) => {
						var content = cache.load_image.end (res);
						if (content == null) {
							set_current (null);
							return;
						}

						var new_image = new Meta.BackgroundActor ();
						new_image.content = content;
						set_current (new_image);
					});
				}
			}

			// update image opacity
			if (all || key_changed == "picture-opacity") {
				if (image != null)
					image.opacity = (uint8)(settings.get_int ("picture-opacity") / 100.0 * 255);

				changed ();
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

				changed ();
			}
		}

		/**
		 * Fade a new image over the old, then destroy the old one and replace it with the new one
		 * if new_image is null, fade out and destroy the current image to show the pattern
		 */
		void set_current (Clutter.Actor? new_image)
		{
			if (new_image == null) {
				if (image != null)
					image.animate (Clutter.AnimationMode.EASE_OUT_QUAD, ANIMATION_TRANSITION_DURATION,
						opacity: 0).completed.connect (() => {
						image.destroy ();

						changed ();
					});
				return;
			}

			new_image.opacity = 0;
			new_image.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.SIZE, 0));
			insert_child_above (new_image, null);

			var dest_opacity = (uint8)(settings.get_int ("picture-opacity") / 100.0 * 255);
			new_image.animate (Clutter.AnimationMode.EASE_OUT_QUAD, ANIMATION_TRANSITION_DURATION,
				opacity: dest_opacity).completed.connect (() => {
				if (image != null)
					image.destroy ();
				image = new_image;

				changed ();
			});
		}

		/**
		 *  translates the string returned from gsettings for the color-shading-type key to the
		 *  appropriate GDesktop.BackgroundShading enum value
		 */
		static GDesktop.BackgroundShading shading_string_to_enum (string shading)
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
		static GDesktop.BackgroundStyle style_string_to_enum (string style)
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
	}
}

