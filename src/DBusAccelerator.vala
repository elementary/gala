//
//  Copyright (C) 2015 Nicolas Bruguier, Corentin Noël
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
	public struct Accelerator
	{
		public string name;
		public Meta.KeyBindingFlags flags;
	}

	[DBus (name="org.gnome.Shell")]
	public class DBusAccelerator
	{
		static DBusAccelerator? instance;
		
		[DBus (visible = false)]
		public static unowned DBusAccelerator init (WindowManager wm)
		{
			if (instance == null)
				instance = new DBusAccelerator (wm);

			return instance;
		}

		public signal void accelerator_activated (uint action, GLib.HashTable<string, Variant> parameters);

		WindowManager wm;
		HashTable<string, uint?> grabbed_accelerators;

		DBusAccelerator (WindowManager _wm)
		{
			wm = _wm;
			grabbed_accelerators = new HashTable<string, uint?> (str_hash, str_equal);

#if HAS_MUTTER330
			wm.get_display ().accelerator_activated.connect (on_accelerator_activated);
#else
			wm.get_screen ().get_display ().accelerator_activated.connect (on_accelerator_activated);
#endif
		}

		void on_accelerator_activated (uint action, uint device_id, uint timestamp)
		{
			foreach (string accelerator in grabbed_accelerators.get_keys ()) {
				if (grabbed_accelerators[accelerator] == action) {
					var parameters = new GLib.HashTable<string, Variant> (null, null);
					parameters.set ("device-id", new Variant.uint32 (device_id));
					parameters.set ("timestamp", new Variant.uint32 (timestamp));

					accelerator_activated (action, parameters);
				}
			}
		}

		public uint grab_accelerator (string accelerator, uint flags) throws DBusError, IOError
		{
			uint? action = grabbed_accelerators[accelerator];

			if (action == null) {
#if HAS_MUTTER332
				action = wm.get_display ().grab_accelerator (accelerator, (Meta.KeyBindingFlags)flags);
#elif HAS_MUTTER330
				action = wm.get_display ().grab_accelerator (accelerator);
#else
				action = wm.get_screen ().get_display ().grab_accelerator (accelerator);
#endif
				if (action > 0) {
					grabbed_accelerators[accelerator] = action;
				}
			}

			return action;
		}

		public uint[] grab_accelerators (Accelerator[] accelerators) throws DBusError, IOError
		{
			uint[] actions = {};

			foreach (unowned Accelerator? accelerator in accelerators) {
				actions += grab_accelerator (accelerator.name, accelerator.flags);
			}

			return actions;
		}

		public bool ungrab_accelerator (uint action) throws DBusError, IOError
		{
			bool ret = false;

			foreach (unowned string accelerator in grabbed_accelerators.get_keys ()) {
				if (grabbed_accelerators[accelerator] == action) {
#if HAS_MUTTER330
					ret = wm.get_display ().ungrab_accelerator (action);
#else
					ret = wm.get_screen ().get_display ().ungrab_accelerator (action);
#endif
					grabbed_accelerators.remove (accelerator);
					break;
				}
			}

			return ret;
		}

		[DBus (name = "ShowOSD")]
		public void show_osd (GLib.HashTable<string, Variant> parameters) throws DBusError, IOError
		{
			int32 monitor_index = -1;
			if (parameters.contains ("monitor"))
				monitor_index = parameters["monitor"].get_int32 ();
			string icon = "";
			if (parameters.contains ("icon"))
				icon = parameters["icon"].get_string ();
			string label = "";
			if (parameters.contains ("label"))
				label = parameters["label"].get_string ();
			int32 level = 0;
			if (parameters.contains ("level"))
				level = parameters["level"].get_int32 ();
			
			//if (monitor_index > -1)
			//	message ("MediaFeedback requested for specific monitor %i which is not supported", monitor_index);
			
			MediaFeedback.send (icon, level);
		}
	}
}
