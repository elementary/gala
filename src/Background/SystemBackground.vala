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
	public class SystemBackground : Object
	{
		public Meta.BackgroundActor actor { get; private set; }

		public signal void loaded ();

		public SystemBackground ()
		{
			actor = new Meta.BackgroundActor ();

			BackgroundCache.get_default ().get_image_content (0, GDesktop.BackgroundStyle.WALLPAPER,
				Config.PKGDATADIR + "/texture.png", Meta.BackgroundEffects.NONE, this, (userdata, content) => {
				var self = userdata as SystemBackground;
				self.actor.content = content;
				self.loaded ();
			});
		}
	}
}

