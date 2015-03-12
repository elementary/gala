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
	public class BackgroundCache : Object
	{
		struct WaitingCallback
		{
			unowned SourceFunc func;
			string hash;
		}

		static BackgroundCache? instance = null;

		public static void init (Meta.Screen screen)
		{
			instance = new BackgroundCache (screen);
		}

		public static unowned BackgroundCache get_default ()
			requires (instance != null)
		{
			return instance;
		}

		public Meta.Screen screen { get; construct; }

		Gee.HashMap<string,Meta.Background> image_cache;
		Gee.HashMap<string,Meta.Background> pattern_cache;
		Gee.LinkedList<WaitingCallback?> waiting_callbacks;

		BackgroundCache (Meta.Screen screen)
		{
			Object (screen: screen);
		}

		construct
		{
			image_cache = new Gee.HashMap<string,Meta.Background> ();
			pattern_cache = new Gee.HashMap<string,Meta.Background> ();
			waiting_callbacks = new Gee.LinkedList<WaitingCallback?> ();
		}

		public async Meta.Background? load_image (string file, int monitor,
			GDesktop.BackgroundStyle style)
		{
			string hash = "%s#%i".printf (file, style);
			Meta.Background? content = image_cache.get (hash);

			if (content != null) {
				// the content has been created, but the file is still loading, so we wait
				if (content.get_filename () == null) {
					waiting_callbacks.add ({ load_image.callback, hash });
					yield;
				}

				return content.copy (monitor, Meta.BackgroundEffects.NONE);
			}

			content = new Meta.Background (screen, monitor, Meta.BackgroundEffects.NONE);

			image_cache.set (hash, content);

			try {
				yield content.load_file_async (file, style, null);
			} catch (Error e) {
				warning (e.message);
				return null;
			}

			foreach (var callback in waiting_callbacks) {
				if (callback.hash == hash) {
					callback.func ();
					waiting_callbacks.remove (callback);
				}
			}

			return content;
		}

		public Meta.Background load_pattern (int monitor, Clutter.Color primary, Clutter.Color secondary,
			GDesktop.BackgroundShading shading_type)
		{
			string hash = "%s#%s#%i".printf (primary.to_string (), secondary.to_string (), shading_type);
			Meta.Background? content = pattern_cache.get (hash);

			if (content != null)
				return content.copy (monitor, Meta.BackgroundEffects.NONE);

			content = new Meta.Background (screen, monitor, Meta.BackgroundEffects.NONE);
			if (shading_type == GDesktop.BackgroundShading.SOLID)
				content.load_color (primary);
			else
				content.load_gradient (shading_type, primary, secondary);

			pattern_cache.set (hash, content);

			return content;
		}
	}
}

