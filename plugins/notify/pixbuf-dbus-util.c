#include <glib-object.h>
#include <glib-object.h>
#include <gdk/gdk.h>

// copied from notify-osd /src/stack.c with some minor changes

GdkPixbuf *
get_pixbuf_from_dbus_variant (GVariant *variant)
{
	GValue data = G_VALUE_INIT;
	GType dbus_icon_t;
	GArray *pixels;
	int width, height, rowstride, bits_per_sample, n_channels, size;
	gboolean has_alpha;
	guchar *copy;
	GdkPixbuf *pixbuf = NULL;

	g_return_val_if_fail (variant != NULL, NULL);

	dbus_icon_t = dbus_g_type_get_struct ("GValueArray",
			G_TYPE_INT,
			G_TYPE_INT,
			G_TYPE_INT,
			G_TYPE_BOOLEAN,
			G_TYPE_INT,
			G_TYPE_INT,
			dbus_g_type_get_collection ("GArray", G_TYPE_UCHAR),
			G_TYPE_INVALID);

	dbus_g_value_parse_g_variant (variant, &data);

	if (G_VALUE_HOLDS (&data, dbus_icon_t)) {
		dbus_g_type_struct_get (&data,
				0, &width,
				1, &height,
				2, &rowstride,
				3, &has_alpha,
				4, &bits_per_sample,
				5, &n_channels,
				6, &pixels,
				G_MAXUINT);

		size = (height - 1) * rowstride + width *
			((n_channels * bits_per_sample + 7) / 8);
		copy = (guchar *) g_memdup (pixels->data, size);

		pixbuf = gdk_pixbuf_new_from_data(copy, GDK_COLORSPACE_RGB,
				has_alpha,
				bits_per_sample,
				width, height,
				rowstride,
				(GdkPixbufDestroyNotify)g_free,
				NULL);
	}

	return pixbuf;
}

