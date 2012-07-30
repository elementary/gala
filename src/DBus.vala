//  
//  Copyright (C) 2012 Tom Beckmann
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
	[DBus (name="org.pantheon.gala")]
	public class DBus
	{
		static DBus? instance;
		static Plugin plugin;
		
		[DBus (visibile = false)]
		public static void init (Plugin _plugin)
		{
			plugin = _plugin;
			
			Bus.own_name (BusType.SESSION, "org.pantheon.gala", BusNameOwnerFlags.NONE,
				(connection) => {
					if (instance == null)
						instance = new DBus ();
					
					try {
						connection.register_object ("/org/pantheon/gala", instance);
					} catch (Error e) { warning (e.message); }
				},
				() => {},
				() => warning ("Could not acquire name\n") );
		}
		
		private DBus ()
		{
		}
		
		public void perform_action (ActionType type)
		{
			plugin.perform_action (type);
		}
	}
}
