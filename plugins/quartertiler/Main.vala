//
//  Copyright (C) 2018 Peter Uithoven
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

namespace Gala.Plugins.QuarterTiler
{
	public class Main : Gala.Plugin
	{
		public override void initialize (Gala.WindowManager wm)
		{
			unowned Meta.Display display = wm.get_screen ().get_display ();

			var settings = new GLib.Settings (Config.SCHEMA + ".keybindings");

			display.add_keybinding ("tile-topleft", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
			display.add_keybinding ("tile-topright", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
			display.add_keybinding ("tile-bottomleft", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
			display.add_keybinding ("tile-bottomright", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
			display.add_keybinding ("tile-top", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
			display.add_keybinding ("tile-bottom", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
		}

		[CCode (instance_pos = -1)]
		void on_initiate (Meta.Display display, Meta.Screen screen,
			Meta.Window? window, Clutter.KeyEvent event, Meta.KeyBinding binding)
		{
			unowned Meta.Window focused_window = display.get_focus_window ();
			bool was_maximized_vertically = focused_window.maximized_vertically;
			bool was_maximized_horizontally = focused_window.maximized_horizontally;
			Meta.Rectangle prev_rect = focused_window.get_frame_rect ();

			if (focused_window.maximized_vertically || focused_window.maximized_horizontally) {
				focused_window.unmaximize (Meta.MaximizeFlags.BOTH);
			}

			if (focused_window.fullscreen) {
				focused_window.unmake_fullscreen ();
			}

			Meta.Rectangle wa = focused_window.get_work_area_current_monitor ();
			int x = wa.x;
			int y = wa.y;
			int width = wa.width / 2;
			int height = wa.height / 2;
			switch (binding.get_name ()) {
				case "tile-topleft":
				default:
					break;
				case "tile-topright":
					x += width;
					break;
				case "tile-bottomleft":
					y += height;
					break;
				case "tile-bottomright":
					x += width;
					y += height;
					break;
				case "tile-top":
				case "tile-bottom":
					if (!was_maximized_vertically) {
						return;
					} else if (was_maximized_horizontally) {
						width = wa.width;
					} else if (prev_rect.x != wa.x) { // right side
						x += width;
					}

					if (binding.get_name () == "tile-bottom") {
						y += height;
					}

					break;
			}

			focused_window.move_resize_frame (true, x, y, width, height);
		}

		public override void destroy ()
		{
		}
	}
}

public Gala.PluginInfo register_plugin ()
{
	return {
		"Quarter tiler",
		"Peter Uithoven <peter@peteruithoven.com>",
		typeof (Gala.Plugins.QuarterTiler.Main),
		Gala.PluginFunction.ADDITION,
		Gala.LoadPriority.IMMEDIATE
	};
}
