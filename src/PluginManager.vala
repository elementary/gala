
namespace Gala
{
	delegate Type RegisterPluginFunction ();

	public class PluginManager : Object
	{
		HashTable<string,Plugin> plugins;
		File plugin_dir;

		WindowManager? wm = null;

		public bool initialized { get; private set; default = false; }

		X.Xrectangle[] regions;

		PluginManager ()
		{
			plugins = new HashTable<string,Plugin> (str_hash, str_equal);

			if (!Module.supported ()) {
				warning ("Modules are not supported on this platform");
				return;
			}

			plugin_dir = File.new_for_path (Config.PLUGINDIR);
			if (!plugin_dir.query_exists ())
				return;

			try {
				var enumerator = plugin_dir.enumerate_children (FileAttribute.STANDARD_NAME, 0);
				FileInfo info;
				while ((info = enumerator.next_file ()) != null) {
					load_module (info.get_name ());
				}
			} catch (Error e) {
				warning (e.message);
			}

			try {
				plugin_dir.monitor_directory (FileMonitorFlags.NONE, null).changed.connect ((file, other_file, type) => {
					if (type == FileMonitorEvent.CREATED) {
						load_module (file.get_basename ());
					}
				});
			} catch (Error e) {
				warning (e.message);
			}
		}

		bool load_module (string plugin_name)
		{
				var path = Module.build_path (plugin_dir.get_path (), plugin_name);
				var module = Module.open (path, ModuleFlags.BIND_LOCAL);
				if (module == null) {
					warning (Module.error ());
					return false;
				}

				void* function;
				module.symbol ("register_plugin", out function);
				if (function == null) {
					warning ("%s failed to register: register_plugin() function not found", plugin_name);
					return false;
				}
				RegisterPluginFunction register = (RegisterPluginFunction)function;

				var type = register ();
				if (type.is_a (typeof (Plugin)) == false) {
					warning ("%s does not return a class of type Plugin", plugin_name);
					return false;
				}

				module.make_resident ();

				var plugin = (Plugin)Object.@new (type);
				plugins.set (plugin_name, plugin);

				if (initialized) {
					initialize_plugin (plugin_name, plugin);
					get_all_regions (true);
				}

				return true;
		}

		void initialize_plugin (string name, Plugin plugin)
		{
			plugin.initialize (wm);
			plugin.notify["region"].connect (() => {
				get_all_regions (true);
			});
		}

		public void initialize (WindowManager _wm)
		{
			wm = _wm;

			plugins.@foreach (initialize_plugin);
			get_all_regions (true);

			initialized = true;
		}

		public X.Xrectangle[] get_all_regions (bool update = false)
		{
			if (update) {
				regions = {};
				plugins.@foreach ((name, plugin) => {
					foreach (var region in plugin.region)
						regions += region;
				});
			}

			return regions;
		}

		static PluginManager? instance = null;
		public static PluginManager get_default ()
		{
			if (instance == null)
				instance = new PluginManager ();

			return instance;
		}
	}
}

