namespace Gala.Plugins.MaskCorners
{
	class Settings : Granite.Services.Settings
	{
		static Settings? instance = null;

		public static unowned Settings get_default ()
		{
			if (instance == null)
				instance = new Settings ();

			return instance;
		}

		public bool enable { get; set; default = true; }
		public int corner_radius { get; set; default = 4; }
		public bool disable_on_fullscreen { get; set; default = true; }
		public bool only_on_primary { get; set; default = false; }

		Settings ()
		{
			base (Config.SCHEMA + ".mask-corners");
		}
	}
}
