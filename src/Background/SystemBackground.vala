
namespace Gala
{
	public class SystemBackground : Meta.BackgroundActor
	{
		public SystemBackground ()
		{
			var cache = BackgroundCache.get_default ();
			cache.load_image.begin (Config.PKGDATADIR + "/texture.png", 0,
				GDesktop.BackgroundStyle.WALLPAPER, (obj, res) => {
				content = cache.load_image.end (res);
			});
		}
	}
}

