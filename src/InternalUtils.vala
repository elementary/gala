//
//  Copyright (C) 2012 Tom Beckmann, Rico Tzschichholz
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

using Gala;

namespace Gala
{
	public class InternalUtils
	{
		/*
		 * Reload shadow settings
		 */
		public static void reload_shadow ()
		{
			var factory = ShadowFactory.get_default ();
			var settings = ShadowSettings.get_default ();
			Meta.ShadowParams shadow;

			//normal focused
			shadow = settings.get_shadowparams ("normal_focused");
			factory.set_params ("normal", true, shadow);

			//normal unfocused
			shadow = settings.get_shadowparams ("normal_unfocused");
			factory.set_params ("normal", false, shadow);

			//menus
			shadow = settings.get_shadowparams ("menu");
			factory.set_params ("menu", false, shadow);
			factory.set_params ("dropdown-menu", false, shadow);
			factory.set_params ("popup-menu", false, shadow);

			//dialog focused
			shadow = settings.get_shadowparams ("dialog_focused");
			factory.set_params ("dialog", true, shadow);
			factory.set_params ("modal_dialog", false, shadow);

			//dialog unfocused
			shadow = settings.get_shadowparams ("normal_unfocused");
			factory.set_params ("dialog", false, shadow);
			factory.set_params ("modal_dialog", false, shadow);
		}

		/**
		 * set the area where clutter can receive events
		 **/
		public static void set_input_area (Screen screen, InputArea area)
		{
			var display = screen.get_display ();

			X.Xrectangle[] rects = {};
			int width, height;
			screen.get_size (out width, out height);
			var geometry = screen.get_monitor_geometry (screen.get_primary_monitor ());

			switch (area) {
				case InputArea.FULLSCREEN:
					X.Xrectangle rect = {0, 0, (ushort)width, (ushort)height};
					rects = {rect};
					break;
				case InputArea.HOT_CORNER:
					var schema = BehaviorSettings.get_default ().schema;

					// if ActionType is NONE make it 0 sized
					ushort tl_size = (schema.get_enum ("hotcorner-topleft") != ActionType.NONE ? 1 : 0);
					ushort tr_size = (schema.get_enum ("hotcorner-topright") != ActionType.NONE ? 1 : 0);
					ushort bl_size = (schema.get_enum ("hotcorner-bottomleft") != ActionType.NONE ? 1 : 0);
					ushort br_size = (schema.get_enum ("hotcorner-bottomright") != ActionType.NONE ? 1 : 0);

					X.Xrectangle topleft = {(short)geometry.x, (short)geometry.y, tl_size, tl_size};
					X.Xrectangle topright = {(short)(geometry.x + geometry.width - 1), (short)geometry.y, tr_size, tr_size};
					X.Xrectangle bottomleft = {(short)geometry.x, (short)(geometry.y + geometry.height - 1), bl_size, bl_size};
					X.Xrectangle bottomright = {(short)(geometry.x + geometry.width - 1), (short)(geometry.y + geometry.height - 1), br_size, br_size};

					rects = {topleft, topright, bottomleft, bottomright};
					break;
				case InputArea.NONE:
				default:
					Util.empty_stage_input_region (screen);
					return;
			}

			// add plugin's requested areas
			if (area == InputArea.FULLSCREEN || area == InputArea.HOT_CORNER) {
				foreach (var rect in PluginManager.get_default ().regions) {
					rects += rect;
				}
			}

			var xregion = X.Fixes.create_region (display.get_xdisplay (), rects);
			Util.set_stage_input_region (screen, xregion);
		}
	}
}
