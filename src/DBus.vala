

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
		
		public DBus ()
		{
			
		}
		
		public void perform_action (ActionType type)
		{
			plugin.perform_action (type);
		}
		
	}
}
