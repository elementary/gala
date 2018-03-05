[CCode (cprefix = "Meta", gir_namespace = "Meta", gir_version = "3.0", lower_case_cprefix = "meta_")]
namespace Meta {
	[CCode (cheader_filename = "meta-blur-actor.h", type_id = "meta_blur_actor_get_type ()")]
	public class BlurActor : Clutter.Actor, Atk.Implementor, Clutter.Animatable, Clutter.Container, Clutter.Scriptable {
        public const int MAX_BLUR_RADIUS;
        public const int MAX_BLUR_ROUNDS;
        public const int DEFAULT_BLUR_RADIUS;
        public const int DEFAULT_BLUR_ROUNDS;

        public static bool get_supported ();

		[CCode (has_construct_function = false, type = "ClutterActor*")]
		public BlurActor (Meta.Screen screen);
		public void set_radius (int radius);
		public void set_rounds (int rounds);
		public void set_enabled (bool enabled);
        public void set_blur_mask (Cairo.Surface? mask);
        public void set_window_actor (Meta.WindowActor window_actor);
        public void set_clip_rect (Cairo.RectangleInt clip_rect);
		[NoAccessorMethod]
		public int radius { get; set; }
		[NoAccessorMethod]
		public Meta.Screen meta_screen { owned get; construct; }
	}
}
