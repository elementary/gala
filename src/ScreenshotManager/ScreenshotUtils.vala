/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

namespace Gala.ScreenshotUtils {
    private Cairo.Format cairo_format_for_content (Cairo.Content content) {
        switch (content) {
            case Cairo.Content.COLOR:
                return Cairo.Format.RGB24;
            case Cairo.Content.ALPHA:
                return Cairo.Format.A8;
            case Cairo.Content.COLOR_ALPHA:
            default:
                return Cairo.Format.ARGB32;
        }
    }

    private Cairo.ImageSurface cairo_surface_coerce_to_image (
        Cairo.Surface surface,
        Cairo.Content content,
        int width,
        int height
    ) {
        var copy = new Cairo.ImageSurface (cairo_format_for_content (content), width, height);

        var cr = new Cairo.Context (copy);
        cr.set_operator (Cairo.Operator.SOURCE);
        cr.set_source_surface (surface, 0, 0);
        cr.paint ();

        return copy;
    }

    public Gdk.Pixbuf? pixbuf_from_surface (
        Cairo.ImageSurface surface,
        int width,
        int height
    ) requires (surface != null && width > 0 && height > 0) {
        var content = surface.get_content () | Cairo.Content.COLOR;
        var has_alpha = (content & Cairo.Content.ALPHA) == Cairo.Content.ALPHA;
        var dest = new Gdk.Pixbuf (RGB, has_alpha, 8, width, height);

        Cairo.ImageSurface new_surface;
        if (surface.get_format () == cairo_format_for_content (content)) {
            warning ("Same surface");
            new_surface = surface;
        } else {
            warning ("New surface");
            new_surface = cairo_surface_coerce_to_image (surface, content, width, height);
        }

        //  new_surface.flush ();
        if (new_surface.status () != Cairo.Status.SUCCESS || dest == null) {
            return null;
        }

        var dest_data = dest.get_pixels ();  
        var dest_stride = dest.get_rowstride ();
        var src_data = surface.get_data ();
        var src_stride = surface.get_stride ();

        warning ("%i", src_data.length);

        if (has_alpha) {
            warning ("Here");
            for (var y = 0; y < height; y++) {
                //  var src = (uint32[]) src_data;

                for (var x = 0; x < width; x++) {
                    //  warning ("%i", src_data[x]);
                    //  warning ("%i", src_data[x] >> 24);
                    //  var alpha = (uint8) (((uint32) src_data[x]) >> 24);

                    //  if (alpha == 0) {
                    //      dest_data[x * 4 + 0] = 0;
                    //      dest_data[x * 4 + 1] = 0;
                    //      dest_data[x * 4 + 2] = 0;
                    //  } else {
                    //      dest_data[x * 4 + 0] = (uint8) (((src[x] & 0xff0000) >> 16) * 255 + alpha / 2) / alpha;
                    //      dest_data[x * 4 + 1] = (uint8) (((src[x] & 0x00ff00) >>  8) * 255 + alpha / 2) / alpha;
                    //      dest_data[x * 4 + 2] = (uint8) (((src[x] & 0x0000ff) >>  0) * 255 + alpha / 2) / alpha;
                    //  }

                    //  dest_data[x * 4 + 3] = alpha;
                }

                //  src_data += (uint8) src_stride;
                //  dest_data += (uint8) dest_stride;
            }
        } else {
            for (var y = 0; y < height; y++) {
                var src = (uint32[]) src_data;

                for (var x = 0; x < width; x++) {
                    dest_data[x * 3 + 0] = (uint8) (src[x] >> 16);
                    dest_data[x * 3 + 1] = (uint8) src[x] >>  8;
                    dest_data[x * 3 + 2] = (uint8) src[x];
                }

                src_data += (uint8) src_stride;
                dest_data += (uint8) dest_stride;
            }
        }

        dest = new Gdk.Pixbuf.from_data (dest_data, RGB, has_alpha, 8, width, height, dest_stride);

        return dest;
    }
}
