//  
//  Copyright (C) 2013 Tom Beckmann
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

using Meta;

namespace Gala
{
	public class BackgroundManager : BackgroundGroup
	{
		public BackgroundManager (Meta.Screen screen)
		{
			screen.monitors_changed.connect (update);
			update (screen);
		}

		void update (Screen screen)
		{
			var n_monitors = screen.get_n_monitors ();

			// create backgrounds we're missing
			for (var i = get_n_children (); i < n_monitors; i++) {
				var background = new Wallpaper (screen, i);
				add_child (background);
			}

			// clear backgrounds we have too much
			while (get_n_children () > n_monitors) {
				get_child_at_index (n_monitors).destroy ();
			}

			// now resize all we got
			for(var i = 0; i < get_n_children (); i++) {
				var monitor_geom = screen.get_monitor_geometry (i);

				var background = get_child_at_index (i) as Background;
				background.actor.set_position (monitor_geom.x, monitor_geom.y);
				background.actor.set_size (monitor_geom.width, monitor_geom.height);
			}
		}
	}

	public abstract class Background : BackgroundGroup
	{
		public int monitor { get; construct set; }
		public BackgroundActor actor { get; construct set; }
		public abstract signal void ready ();

		public Background (int monitor)
		{
			Object (monitor: monitor, actor: new BackgroundActor ());
			add_child (actor);
		}
	}

	public class Wallpaper : Background
	{
		public Wallpaper (Screen screen, int monitor)
		{
			base (monitor);

			var settings = BackgroundSettings.get_default ();
			BackgroundCache.get_default ().set_background (this, screen,
				File.new_for_uri (settings.picture_uri).get_path (),
				translate_style (settings.picture_options));
		}

		GDesktop.BackgroundStyle translate_style (string style)
		{
			switch (style) {
				case "zoom":
					return GDesktop.BackgroundStyle.ZOOM;
				case "wallpaper":
					return GDesktop.BackgroundStyle.WALLPAPER;
				case "centered":
					return GDesktop.BackgroundStyle.CENTERED;
				case "scaled":
					return GDesktop.BackgroundStyle.SCALED;
				case "stretched":
					return GDesktop.BackgroundStyle.STRETCHED;
				case "spanned":
					return GDesktop.BackgroundStyle.SPANNED;
			}
			return GDesktop.BackgroundStyle.NONE;
		}
	}

	public class SystemBackground : Background
	{
		public SystemBackground (Screen screen)
		{
			base (0);

			BackgroundCache.get_default ().set_background (this, screen,
				Config.PKGDATADIR + "/texture.png", GDesktop.BackgroundStyle.WALLPAPER);
		}
	}
}
