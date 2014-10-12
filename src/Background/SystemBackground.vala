
namespace Gala
{
	public class SystemBackground : Meta.BackgroundActor
	{
		static Meta.Background? system_background = null;

		public signal void loaded ();

		public SystemBackground (Meta.Screen screen)
		{
			Object (meta_screen: screen, monitor: 0);

			var filename = Config.PKGDATADIR + "/texture.png";

			if (system_background == null) {
				system_background = new Meta.Background (screen);
				system_background.set_filename (filename, GDesktop.BackgroundStyle.WALLPAPER);
			}

			background = system_background;

			var cache = Meta.BackgroundImageCache.get_default ();
			var image = cache.load (filename);
			if (image.is_loaded ()) {
				image = null;
				Idle.add(() => {
					loaded ();
					return false;
				});
			} else {
				ulong handler = 0;
				handler = image.loaded.connect (() => {
					loaded ();
					SignalHandler.disconnect (image, handler);
					image = null;
				});
			}
		}
	}
}

