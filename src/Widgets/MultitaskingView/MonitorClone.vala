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

using Clutter;
using Meta;

namespace Gala
{
	public class MonitorClone : Actor
	{
		public WindowManager wm { get; construct; }
		public Screen screen { get; construct; }
		public int monitor { get; construct; }

		public signal void window_selected (Window window);

		TiledWindowContainer window_container;
		Background background;

		public MonitorClone (WindowManager wm, Screen screen, int monitor)
		{
			Object (wm: wm, monitor: monitor, screen: screen);

			reactive = true;

			background = new Background (screen, monitor, BackgroundSettings.get_default ().schema);
			background.set_easing_duration (300);

			window_container = new TiledWindowContainer (wm.window_stacking_order);
			window_container.window_selected.connect ((w) => { window_selected (w); });

			wm.windows_restacked.connect (() => {
				window_container.stacking_order = wm.window_stacking_order;
			});

			screen.window_entered_monitor.connect (window_entered);
			screen.window_left_monitor.connect (window_left);

			foreach (var window_actor in Compositor.get_window_actors (screen)) {
				var window = window_actor.get_meta_window ();
				if (window.get_monitor () == monitor) {
					window_entered (monitor, window);
				}
			}

			add_child (background);
			add_child (window_container);

			var drop = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
			add_action (drop);

			update_allocation ();
		}

		public void update_allocation ()
		{
			var monitor_geometry = screen.get_monitor_geometry (monitor);

			set_position (monitor_geometry.x, monitor_geometry.y);
			set_size (monitor_geometry.width, monitor_geometry.height);
			window_container.set_size (monitor_geometry.width, monitor_geometry.height);
		}

		public void open ()
		{
			window_container.opened = true;
			// background.opacity = 0; TODO consider this option
		}

		public void close ()
		{
			window_container.opened = false;
			background.opacity = 255;
		}

		void window_left (int window_monitor, Window window)
		{
			if (window_monitor != monitor)
				return;

			window_container.remove_window (window);
		}

		void window_entered (int window_monitor, Window window)
		{
			if (window_monitor != monitor || window.window_type != WindowType.NORMAL)
				return;

			window_container.add_window (window);
		}
	}
}

