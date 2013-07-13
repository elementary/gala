
namespace Gala
{
	class CachedBackground : Object
	{
		public Meta.Background background;
		public bool loaded;
		public string file;
		public GDesktop.BackgroundStyle style;
		public Gee.LinkedList<Background> to_be_served;

		public CachedBackground (Meta.Background _background, string _file,
			GDesktop.BackgroundStyle _style)
		{
			background = _background;
			loaded = false;
			file = _file;
			style = _style;
			to_be_served = new Gee.LinkedList<Background> ();
		}
	}

	public class BackgroundCache : Object
	{
		Gee.LinkedList<CachedBackground> cache;

		static BackgroundCache? instance = null;

		BackgroundCache ()
		{
			cache = new Gee.LinkedList<CachedBackground> ();
		}

		public static BackgroundCache get_default ()
		{
			if (instance == null)
				instance = new BackgroundCache ();

			return instance;
		}

		public void set_background (Background actor, Meta.Screen screen, string file,
			GDesktop.BackgroundStyle style)
		{
			foreach (var cached in cache) {
				if (cached.file == file
					&& cached.style == style) {
					if (!cached.loaded) {

						cached.to_be_served.add (actor);
					} else {
						actor.content = cached.background.copy (actor.monitor,
							Meta.BackgroundEffects.NONE);
						actor.ready ();
					}

					return;
				}
			}

			var content = new Meta.Background (screen, actor.monitor, Meta.BackgroundEffects.NONE);
			actor.actor.content = content;
			var cached = new CachedBackground (content, file, style);
			cached.to_be_served.add (actor);
			content.load_file_async.begin (file, style, null, background_loaded);

			cache.add (cached);
		}

		void background_loaded (Object? obj, AsyncResult res)
		{
			var content = obj as Meta.Background;

			try {
				content.load_file_async.end (res);
			} catch (Error e) { warning (e.message); }

			CachedBackground? cached = null;
			foreach (var c in cache) {
				if (c.file == content.get_filename ()
					&& c.style == content.get_style ()) {
					cached = c;
					break;
				}
			}

			if (cached == null)
				return;

			cached.loaded = true;

			foreach (var background in cached.to_be_served) {
				if (background.actor.content == null)
					background.actor.content = content.copy (background.monitor,
						Meta.BackgroundEffects.NONE);
				background.ready ();
			}
		}
	}
}
