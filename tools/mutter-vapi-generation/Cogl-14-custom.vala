namespace Cogl {
	public struct Color {
		[Version (since = "1.4")]
		[CCode (cname="cogl_color_init_from_4f")]
		public Color.from_4f (float red, float green, float blue, float alpha);
		[Version (since = "1.4")]
		[CCode (cname="cogl_color_init_from_4fv")]
		public Color.from_4fv (float color_array);
		[Version (since = "1.16")]
		[CCode (cname="cogl_color_init_from_hsl")]
		public Color.from_hsl (float hue, float saturation, float luminance);
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	[Version (since = "1.6")]
	public struct VertexP2 {
		public float x;
		public float y;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	[Version (since = "1.6")]
	public struct VertexP2C4 {
		public float x;
		public float y;
		public uint8 r;
		public uint8 g;
		public uint8 b;
		public uint8 a;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	[Version (since = "1.6")]
	public struct VertexP2T2 {
		public float x;
		public float y;
		public float s;
		public float t;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	[Version (since = "1.6")]
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
	[Version (since = "1.6")]
	public struct VertexP3 {
		public float x;
		public float y;
		public float z;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	[Version (since = "1.6")]
	public struct VertexP3C4 {
		public float x;
		public float y;
		public float z;
		public uint8 r;
		public uint8 g;
		public uint8 b;
		public uint8 a;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	[Version (since = "1.6")]
	public struct VertexP3T2 {
		public float x;
		public float y;
		public float z;
		public float s;
		public float t;
	}
	[CCode (cheader_filename = "cogl/cogl.h", has_type_id = false)]
	[Version (since = "1.6")]
	public struct VertexP3T2C4 {
		public float x;
		public float y;
		public float z;
		public float s;
		public float t;
		public uint8 r;
		public uint8 g;
		public uint8 b;
		public uint8 a;
	}
	[CCode (cheader_filename = "cogl/cogl.h", cprefix = "COGL_PIXEL_FORMAT_", type_id = "cogl_pixel_format_get_type ()")]
	public enum PixelFormat {
		CAIRO_ARGB32_COMPAT;
	}
}
