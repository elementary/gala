namespace Clutter {
	public struct Color {
		[CCode (cname = "_vala_clutter_color_from_hls")]
		public static Clutter.Color? from_hls (float hue, float luminance, float saturation) {
			var color = Clutter.Color.alloc ();
			color.init_from_hls (hue, luminance, saturation);
			return color;
		}
		[CCode (cname = "_vala_clutter_color_from_pixel")]
		public static Clutter.Color? from_pixel (uint32 pixel) {
			var color = Clutter.Color.alloc ();
			color.init_from_pixel (pixel);
			return color;
		}
		[CCode (cname = "_vala_clutter_color_from_string")]
		public static Clutter.Color? from_string (string str) {
			var color = Clutter.Color.alloc ();
			color.init_from_string (str);
			return color;
		}
		[CCode (cname = "clutter_color_from_string")]
		public bool parse_string (string str);
	}
}
