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

namespace Gala
{
	public class SystemBackground : Meta.BackgroundActor
	{
		static Meta.Background? system_background = null;

		public signal void loaded ();

		public SystemBackground (Meta.Screen screen)
		{
			Object (meta_screen: screen, monitor: 0);
		}

		construct
		{
			var filename = Config.PKGDATADIR + "/texture.png";

			if (system_background == null) {
				system_background = new Meta.Background (meta_screen);
				system_background.set_filename (filename, GDesktop.BackgroundStyle.WALLPAPER);
			}

			background = system_background;

			var cache = Meta.BackgroundImageCache.get_default ();
			var image = cache.load (filename);
			if (image.is_loaded ()) {
				image = null;
				Idle.add(() => {
					loaded ();
					return false;
				});
			} else {
				ulong handler = 0;
				handler = image.loaded.connect (() => {
					loaded ();
					SignalHandler.disconnect (image, handler);
					image = null;
				});
			}
		}
	}
}

