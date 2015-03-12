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

namespace Gala.Plugins.Zoom
{
	public class Main : Gala.Plugin
	{
		const uint MOUSE_POLL_TIME = 50;

		Gala.WindowManager? wm = null;

		uint mouse_poll_timer = 0;
		float current_zoom = 1.0f;

		public override void initialize (Gala.WindowManager wm)
		{
			this.wm = wm;
			var display = wm.get_screen ().get_display ();
			var schema = new GLib.Settings (Config.SCHEMA + ".keybindings");

			display.add_keybinding ("zoom-in", schema, 0, (Meta.KeyHandlerFunc) zoom_in);
			display.add_keybinding ("zoom-out", schema, 0, (Meta.KeyHandlerFunc) zoom_out);
		}

		public override void destroy ()
		{
			if (wm == null)
				return;

			var display = wm.get_screen ().get_display ();

			display.remove_keybinding ("zoom-in");
			display.remove_keybinding ("zoom-out");

			if (mouse_poll_timer > 0)
				Source.remove (mouse_poll_timer);
			mouse_poll_timer = 0;
		}

		[CCode (instance_pos = -1)]
		void zoom_in (Meta.Display display, Meta.Screen screen,
#if HAS_MUTTER314
			Meta.Window? window, Clutter.KeyEvent event, Meta.KeyBinding binding)
#else
			Meta.Window? window, X.Event event, Meta.KeyBinding binding)
#endif
		{
			zoom (true);
		}

		[CCode (instance_pos = -1)]
		void zoom_out (Meta.Display display, Meta.Screen screen,
#if HAS_MUTTER314
			Meta.Window? window, Clutter.KeyEvent event, Meta.KeyBinding binding)
#else
			Meta.Window? window, X.Event event, Meta.KeyBinding binding)
#endif
		{
			zoom (false);
		}

		void zoom (bool @in)
		{
			// Nothing to do if zooming out of our bounds is requested
			if (current_zoom <= 1.0f && !@in)
				return;
			else if (current_zoom >= 2.5f && @in)
				return;

			var wins = wm.ui_group;

			// Add timer to poll current mouse position to reposition window-group
			// to show requested zoomed area
			if (mouse_poll_timer == 0) {
				float mx, my;
				var client_pointer = Gdk.Display.get_default ().get_device_manager ().get_client_pointer ();
				client_pointer.get_position (null, out mx, out my);
				wins.scale_center_x = mx;
				wins.scale_center_y = my;

				mouse_poll_timer = Timeout.add (MOUSE_POLL_TIME, () => {
					client_pointer.get_position (null, out mx, out my);
					if (wins.scale_center_x == mx && wins.scale_center_y == my)
						return true;

					wins.animate (Clutter.AnimationMode.LINEAR, MOUSE_POLL_TIME, scale_center_x : mx, scale_center_y : my);

					return true;
				});
			}

			current_zoom += (@in ? 0.5f : -0.5f);

			if (current_zoom <= 1.0f) {
				current_zoom = 1.0f;

				if (mouse_poll_timer > 0)
					Source.remove (mouse_poll_timer);
				mouse_poll_timer = 0;

				wins.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 300, scale_x : 1.0f, scale_y : 1.0f).completed.connect (() => {
					wins.scale_center_x = 0.0f;
					wins.scale_center_y = 0.0f;
				});

				return;
			}

			wins.animate (Clutter.AnimationMode.EASE_OUT_CUBIC, 300, scale_x : current_zoom, scale_y : current_zoom);
		}
	}
}

public Gala.PluginInfo register_plugin ()
{
	return Gala.PluginInfo () {
		name = "Zoom",
		author = "Gala Developers",
		plugin_type = typeof (Gala.Plugins.Zoom.Main),
		provides = Gala.PluginFunction.ADDITION,
		load_priority = Gala.LoadPriority.IMMEDIATE
	};
}

