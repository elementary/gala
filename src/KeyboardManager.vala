//
//  Copyright (C) 2016 Santiago León
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
	public class KeyboardManager : Object
	{
		static KeyboardManager? instance;
		static VariantType sources_variant_type;

		public static void init ()
		{
			if (instance == null) {
				instance = new KeyboardManager ();
			}
		}

		static construct
		{
			sources_variant_type = new VariantType ("a(ss)");
		}

		GLib.Settings settings;

		KeyboardManager ()
		{
			Object ();
		}
		
		construct
		{
			var schema = GLib.SettingsSchemaSource.get_default ().lookup ("org.gnome.desktop.input-sources", true);
			return_if_fail (schema != null);
			
			settings = new GLib.Settings.full (schema, null, null);
			Signal.connect (settings, "changed", (Callback) set_keyboard_layout, this);

			set_keyboard_layout (settings, "current");
		}

		[CCode (instance_pos = -1)]
		void set_keyboard_layout (GLib.Settings settings, string key)
		{
			if (!(key == "current" || key == "source" || key == "xkb-options"))
				return;

			string layout = "us", variant = "", options = "";

			var sources = settings.get_value ("sources");
			return_if_fail (sources.is_of_type (sources_variant_type));

			var current = settings.get_uint ("current");
			unowned string? type = null, name = null;
			if (sources.n_children () > current)
				sources.get_child (current, "(&s&s)", out type, out name);
			if (type == "xkb") {
				string[] arr = name.split ("+", 2);
				layout = arr[0];
				variant = arr[1] ?? "";
			}

			var xkb_options = settings.get_strv ("xkb-options");
			if (xkb_options.length > 0)
				options = string.joinv (",", xkb_options);

			// Needed to make common keybindings work on non-latin layouts
			if (layout != "us" || variant != "") {
				layout = layout + ",us";
				variant = variant + ",";
			}

			Meta.Backend.get_backend ().set_keymap (layout, variant, options);
		}
	}
}
