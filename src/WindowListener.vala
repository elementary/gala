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

using Gala;
using Meta;

namespace Gala
{
	public class WindowListener : Object
	{
		static WindowListener? instance = null;

		public static void init (Screen screen)
		{
			if (instance != null)
				return;

			instance = new WindowListener ();

			foreach (var actor in Compositor.get_window_actors (screen)) {
				var window = actor.get_meta_window ();

				if (window.on_all_workspaces)
					instance.listen_on_window (window);

				if (window.window_type == WindowType.NORMAL)
					instance.monitor_window (window);
			}

			screen.get_display ().window_created.connect ((window) => {
				if (window.window_type == WindowType.NORMAL)
					instance.monitor_window (window);
			});
		}

		public static WindowListener get_default ()
			requires (instance != null)
		{
			return instance;
		}

		public signal void window_no_longer_on_all_workspaces (Window window);

		public Meta.Rectangle last_maximized_window_frame_rect;
		public Meta.Rectangle last_maximized_window_buffer_rect;

		Gee.List<Window> listened_windows_sticky;

		WindowListener ()
		{
			listened_windows_sticky = new Gee.LinkedList<Window> ();
		}

		public void listen_on_window (Window window)
		{
			if (!window.on_all_workspaces)
				return;

			window.notify["on-all-workspaces"].connect (window_on_all_workspaces_changed);
			window.unmanaged.connect (window_removed);

			listened_windows_sticky.add (window);
		}

		void window_on_all_workspaces_changed (Object object, ParamSpec param)
		{
			var window = (Window) object;

			if (window.on_all_workspaces)
				return;

			window.notify.disconnect (window_on_all_workspaces_changed);
			window.unmanaged.disconnect (sticky_window_removed);
			listened_windows_sticky.remove (window);

			window_no_longer_on_all_workspaces (window);
		}

		void monitor_window (Window window)
		{
			window.notify["maximized-horizontally"].connect (window_maximized_changed);
			window.notify["maximized-vertically"].connect (window_maximized_changed);
			window.unmanaged.connect (window_removed);
		}

		void window_maximized_changed (Object object, ParamSpec pspec)
		{
			var window = (Window) object;

#if HAS_MUTTER312
			last_maximized_window_frame_rect = window.get_frame_rect ();
#else
			last_maximized_window_frame_rect = window.get_outer_rect ();
#endif

#if HAS_MUTTER314
			last_maximized_window_buffer_rect = window.get_buffer_rect ();
#else
			last_maximized_window_buffer_rect = window.get_input_rect ();
#endif
		}

		void window_removed (Window window)
		{
			window.notify["maximized-horizontally"].disconnect (window_maximized_changed);
			window.notify["maximized-vertically"].disconnect (window_maximized_changed);
			window.unmanaged.disconnect (window_removed);
		}

		void sticky_window_removed (Window window)
		{
			listened_windows_sticky.remove (window);
		}
	}
}

