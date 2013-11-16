
namespace Gala
{
	public class BackgroundManager : Meta.BackgroundGroup
	{
		public Meta.Screen screen { get; construct set; }

		public BackgroundManager (Meta.Screen screen)
		{
			Object (screen: screen);

			update ();
			screen.monitors_changed.connect (update);
		}

		void update ()
		{
			remove_all_children ();

			var settings = BackgroundSettings.get_default ().schema;

			for (var i = 0; i < screen.get_n_monitors (); i++) {
				var geom = screen.get_monitor_geometry (i);
				var background = new Background (screen, i, settings);

				background.set_position (geom.x, geom.y);
				background.set_size (geom.width, geom.height);

				add_child (background);
			}
		}
	}
}

