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
		public uint flags;
	}

	[DBus (name="org.gnome.Shell")]
	public class DBusAccelerator
	{
		static DBusAccelerator? instance;
		static WindowManager wm;

		[DBus (visible = false)]
		public static void init (WindowManager _wm)
		{
			wm = _wm;

			Bus.own_name (BusType.SESSION, "org.gnome.Shell", BusNameOwnerFlags.NONE,
				(connection) => {
					if (instance == null)
						instance = new DBusAccelerator ();

					try {
						connection.register_object ("/org/gnome/Shell", instance);
					} catch (Error e) { warning (e.message); }
				},
				() => {},
				() => critical ("Could not acquire name") );
		}

#if HAS_GSD316
		public signal void accelerator_activated (uint action, GLib.HashTable<string, Variant> parameters);
#else
		public signal void accelerator_activated (uint action, uint device_id, uint timestamp);
#endif

		HashTable<string, uint?> grabbed_accelerators;

		DBusAccelerator ()
		{
			grabbed_accelerators = new HashTable<string, uint> (str_hash, str_equal);

			wm.get_screen ().get_display ().accelerator_activated.connect (on_accelerator_activated);
		}

		void on_accelerator_activated (uint action, uint device_id, uint timestamp)
		{
			foreach (string accelerator in grabbed_accelerators.get_keys ()) {
				if (grabbed_accelerators[accelerator] == action) {
#if HAS_GSD316
					var parameters = new GLib.HashTable<string, Variant> (null, null);
					parameters.set ("device-id", new Variant.uint32 (device_id));
					parameters.set ("timestamp", new Variant.uint32 (timestamp));

					accelerator_activated (action, parameters);
#else
					accelerator_activated (action, device_id, timestamp);
#endif
				}
			}
		}

		public uint grab_accelerator (string accelerator, uint flags)
		{
			uint? action = grabbed_accelerators[accelerator];

			if (action == null) {
				action = wm.get_screen ().get_display ().grab_accelerator (accelerator);
				if (action > 0) {
					grabbed_accelerators[accelerator] = action;
				}
			}

			return action;
		}

		public uint[] grab_accelerators (Accelerator[] accelerators)
		{
			uint[] actions = {};

			foreach (unowned Accelerator? accelerator in accelerators) {
				actions += grab_accelerator (accelerator.name, accelerator.flags);
			}

			return actions;
		}

		public bool ungrab_accelerator (uint action)
		{
			bool ret = false;

			foreach (unowned string accelerator in grabbed_accelerators.get_keys ()) {
				if (grabbed_accelerators[accelerator] == action) {
					ret = wm.get_screen ().get_display ().ungrab_accelerator (action);
					grabbed_accelerators.remove (accelerator);
					break;
				}
			}

			return ret;
		}
	}
}
