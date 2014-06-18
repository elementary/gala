using Clutter;

namespace Gala
{
	public class ShadowEffect : Effect
	{
		// the sizes of the textures often repeat, especially for the background actor
		// so we keep a cache to avoid creating the same texture all over again.
		// TODO keep track of user numbers and free shadows
		static Gee.HashMap<string,Cogl.Texture> shadow_cache;

		public int shadow_size { get; construct; }
		public int shadow_spread { get; construct; }

		public float scale_factor { get; set; default = 1; }

		Cogl.Texture? shadow = null;

		public ShadowEffect (int actor_width, int actor_height, int shadow_size, int shadow_spread)
		{
			Object (shadow_size: shadow_size, shadow_spread: shadow_spread);

			if (shadow_cache == null) {
				shadow_cache = new Gee.HashMap<string,Cogl.Texture> ();
			}

			var width = actor_width + shadow_size * 2;
			var height = actor_height + shadow_size * 2;

			var key = "%ix%i:%i:%i".printf (width, height, shadow_size, shadow_spread);
			if ((shadow = shadow_cache.@get (key)) != null)
				return;

			// fill a new texture for this size
			var buffer = new Granite.Drawing.BufferSurface (width, height);
			buffer.context.rectangle (shadow_size - shadow_spread, shadow_size - shadow_spread,
				actor_width + shadow_spread * 2, actor_height + shadow_spread * 2);
			buffer.context.set_source_rgba (0, 0, 0, 0.7);
			buffer.context.fill ();

			buffer.exponential_blur (shadow_size / 2);

			var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
			var cr = new Cairo.Context (surface);

			cr.set_source_surface (buffer.surface, 0, 0);
			cr.paint ();

			shadow = new Cogl.Texture.from_data (width, height, 0, Cogl.PixelFormat.BGRA_8888_PRE,
				Cogl.PixelFormat.ANY, surface.get_stride (), surface.get_data ());

			shadow_cache.@set (key, shadow);
		}

		public override void paint (EffectPaintFlags flags)
		{
			var size = shadow_size * scale_factor;

			Cogl.set_source_texture (shadow);
			Cogl.rectangle (-size, -size, actor.width + size, actor.height + size);

			actor.continue_paint ();
		}
	}
}

