namespace Cogl {
	public struct Color {
		[CCode (cname="cogl_color_init_from_4f")]
		public Color.from_4f (float red, float green, float blue, float alpha);
		[CCode (cname="cogl_color_init_from_hsl")]
		public Color.from_hsl (float hue, float saturation, float luminance);
		[CCode (cname = "_vala_cogl_color_from_string")]
		public static Cogl.Color? from_string (string str) {
			Cogl.Color color = {};
			if (color.init_from_string (str))
				return color;

			return null;
		}
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	public struct VertexP2 {
		public float x;
		public float y;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	public struct VertexP2C4 {
		public float x;
		public float y;
		public uint8 r;
		public uint8 g;
		public uint8 b;
		public uint8 a;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	public struct VertexP2T2 {
		public float x;
		public float y;
		public float s;
		public float t;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	public struct VertexP2T2C4 {
		public float x;
		public float y;
		public float s;
		public float t;
		public uint8 r;
		public uint8 g;
		public uint8 b;
		public uint8 a;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	public struct VertexP3 {
		public float x;
		public float y;
		public float z;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	public struct VertexP3T2 {
		public float x;
		public float y;
		public float z;
		public float s;
		public float t;
	}
	[CCode (cheader_filename = "cogl/cogl.h", cprefix = "COGL_PIXEL_FORMAT_", type_id = "cogl_pixel_format_get_type ()")]
	public enum PixelFormat {
		CAIRO_ARGB32_COMPAT;
	}
}
