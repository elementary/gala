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
	public class TiledWindowContainer : Actor
	{
		public signal void window_selected (Window window);

		public int padding_top { get; set; default = 12; }
		public int padding_left { get; set; default = 12; }
		public int padding_right { get; set; default = 12; }
		public int padding_bottom { get; set; default = 12; }

		bool _opened;
		public bool opened {
			get {
				return _opened;
			}
			set {
				if (value == _opened)
					return;

				_opened = value;

				if (_opened) {
					// hide the highlight when opened
					if (_current_window != null)
						_current_window.active = false;

					// make sure our windows are where they belong in case they were moved
					// while were closed.
					foreach (var window in get_children ()) {
						((TiledWindow) window).transition_to_original_state (false);
					}

					reflow ();
				} else {
					foreach (var window in get_children ())
						((TiledWindow) window).transition_to_original_state (true);
				}
			}
		}

		TiledWindow? _current_window = null;
		public Window? current_window {
			get {
				return _current_window != null ? _current_window.window : null;
			}
			set {
				foreach (var child in get_children ()) {
					unowned TiledWindow tiled_window = (TiledWindow) child;
					if (tiled_window.window == value) {
						_current_window = tiled_window;
						break;
					}
				}
			}
		}

		public TiledWindowContainer ()
		{
		}

		public void add_window (Window window)
		{
			unowned Meta.Display display = window.get_display ();
			var children = get_children ();
			
			GLib.SList<unowned Meta.Window> windows = new GLib.SList<unowned Meta.Window> ();
			foreach (unowned Actor child in children) {
				unowned TiledWindow tw = (TiledWindow) child;
				windows.prepend (tw.window);
			}
			windows.prepend (window);
			windows.reverse ();
			
			var windows_ordered = display.sort_windows_by_stacking (windows);
			
			var new_window = new TiledWindow (window);

			new_window.selected.connect (window_selected_cb);
			new_window.destroy.connect (window_destroyed);
			new_window.request_reposition.connect (reflow);

			var added = false;
			unowned Meta.Window? target = null;
			foreach (unowned Meta.Window w in windows_ordered) {
				if (w != window) {
					target = w;
					continue;
				}
				break;
			}

			foreach (unowned Actor child in children) {
				unowned TiledWindow tw = (TiledWindow) child;
				if (target == tw.window) {
					insert_child_above (new_window, tw);
					added = true;
					break;
				}
			}

			// top most or no other children
			if (!added)
				add_child (new_window);

			reflow ();
		}

		public void remove_window (Window window)
		{
			foreach (var child in get_children ()) {
				if (((TiledWindow) child).window == window) {
					remove_child (child);
					break;
				}
			}

			reflow ();
		}

		void window_selected_cb (TiledWindow tiled)
		{
			window_selected (tiled.window);
		}

		void window_destroyed (Actor actor)
		{
			var window = actor as TiledWindow;
			if (window == null)
				return;

			window.destroy.disconnect (window_destroyed);
			window.selected.disconnect (window_selected_cb);

			Idle.add (() => {
				reflow ();
				return false;
			});
		}

		public void restack_windows (Screen screen)
		{
			unowned Meta.Display display = screen.get_display ();
			var children = get_children ();

			GLib.SList<unowned Meta.Window> windows = new GLib.SList<unowned Meta.Window> ();
			foreach (unowned Actor child in children) {
				unowned TiledWindow tw = (TiledWindow) child;
				windows.prepend (tw.window);
			}

			var windows_ordered = display.sort_windows_by_stacking (windows);
			windows_ordered.reverse ();

			foreach (unowned Meta.Window window in windows_ordered) {
				var i = 0;
				foreach (unowned Actor child in children) {
					if (((TiledWindow) child).window == window) {
						set_child_at_index (child, i);
						children.remove (child);
						i++;
						break;
					}
				}
			}
		}

		public void reflow ()
		{
			if (!opened)
				return;

			var windows = new List<InternalUtils.TilableWindow?> ();
			foreach (var child in get_children ()) {
				unowned TiledWindow window = (TiledWindow) child;
				windows.prepend ({ window.window.get_outer_rect (), window });
			}
			windows.reverse ();

			if (windows.length () < 1)
				return;

			Meta.Rectangle area = {
				padding_left,
				padding_top,
				(int)width - padding_left - padding_right,
				(int)height - padding_top - padding_bottom
			};

			var window_positions = InternalUtils.calculate_grid_placement (area, windows);

			foreach (var tilable in window_positions) {
				unowned TiledWindow window = (TiledWindow) tilable.id;
				window.take_slot (tilable.rect);
				window.place_widgets (tilable.rect.width, tilable.rect.height);
			}
		}

		public void select_next_window (MotionDirection direction)
		{
			if (get_n_children () < 1)
				return;

			if (_current_window == null) {
				_current_window = (TiledWindow) get_child_at_index (0);
				return;
			}

			var current_rect = _current_window.slot;

			TiledWindow? closest = null;
			foreach (var window in get_children ()) {
				if (window == _current_window)
					continue;

				var window_rect = ((TiledWindow) window).slot;

				switch (direction) {
					case MotionDirection.LEFT:
						if (window_rect.x > current_rect.x)
							continue;

						// test for vertical intersection
						if (window_rect.y + window_rect.height > current_rect.y
							&& window_rect.y < current_rect.y + current_rect.height) {

							if (closest == null
								|| closest.slot.x < window_rect.x)
								closest = (TiledWindow) window;
						}
						break;
					case MotionDirection.RIGHT:
						if (window_rect.x < current_rect.x)
							continue;

						// test for vertical intersection
						if (window_rect.y + window_rect.height > current_rect.y
							&& window_rect.y < current_rect.y + current_rect.height) {

							if (closest == null
								|| closest.slot.x > window_rect.x)
								closest = (TiledWindow) window;
						}
						break;
					case MotionDirection.UP:
						if (window_rect.y > current_rect.y)
							continue;

						// test for horizontal intersection
						if (window_rect.x + window_rect.width > current_rect.x
							&& window_rect.x < current_rect.x + current_rect.width) {

							if (closest == null
								|| closest.slot.y < window_rect.y)
								closest = (TiledWindow) window;
						}
						break;
					case MotionDirection.DOWN:
						if (window_rect.y < current_rect.y)
							continue;

						// test for horizontal intersection
						if (window_rect.x + window_rect.width > current_rect.x
							&& window_rect.x < current_rect.x + current_rect.width) {

							if (closest == null
								|| closest.slot.y > window_rect.y)
								closest = (TiledWindow) window;
						}
						break;
				}
			}

			if (closest == null)
				return;

			if (_current_window != null)
				_current_window.active = false;

			closest.active = true;
			_current_window = closest;
		}

		public void activate_selected_window ()
		{
			if (_current_window != null)
				_current_window.selected ();
		}
	}
}

