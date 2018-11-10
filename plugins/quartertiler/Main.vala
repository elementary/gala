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

using Clutter;
using Meta;

namespace Gala.Plugins.QuarterTiler
{
	public class Main : Gala.Plugin
	{
		Gala.WindowManager? wm = null;
		Screen screen;

		public override void initialize (Gala.WindowManager wm)
		{
			this.wm = wm;
			screen = wm.get_screen ();
			Display display = screen.get_display ();
			var settings = new GLib.Settings (Config.SCHEMA + ".keybindings");
			display.add_keybinding ("tile-topleft", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
			display.add_keybinding ("tile-topright", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
			display.add_keybinding ("tile-bottomleft", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
			display.add_keybinding ("tile-bottomright", settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
		}

		[CCode (instance_pos = -1)]
		void on_initiate (Meta.Display display, Meta.Screen screen,
			Meta.Window? window, Clutter.KeyEvent event, Meta.KeyBinding binding)
		{
			Window focused_window = display.get_focus_window ();
			if (!focused_window.allows_move () || !focused_window.allows_resize ()){
				return;
			}

			if (focused_window.maximized_vertically || focused_window.maximized_horizontally) {
				focused_window.unmaximize (MaximizeFlags.BOTH);
			}

			Meta.Rectangle wa = focused_window.get_work_area_current_monitor ();

			int x = wa.x;
			int y = wa.y;
			var width = wa.width / 2;
			var height = wa.height / 2;
			switch (binding.get_name ()) {
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
	return
	{
		"Quarter tiler",
		"Peter Uithoven <peter@peteruithoven.com>",
		typeof (Gala.Plugins.QuarterTiler.Main),
		Gala.PluginFunction.ADDITION,
		Gala.LoadPriority.IMMEDIATE
	};
}
