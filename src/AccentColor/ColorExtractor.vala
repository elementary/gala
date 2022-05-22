/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class Gala.ColorExtractor : Object {
    private const double PERCENTAGE_SAMPLE_PIXELS = 0.01;

    public Gdk.Pixbuf? pixbuf { get; construct set; }
    public Drawing.Color? primary_color { get; construct set; }

    private Gee.List<Drawing.Color> pixels;

    public ColorExtractor.from_pixbuf (Gdk.Pixbuf pixbuf) {
        Object (pixbuf: pixbuf);

        pixels = convert_pixels_to_rgb (pixbuf.get_pixels_with_length (), pixbuf.has_alpha);
    }

    public ColorExtractor.from_primary_color (Drawing.Color primary_color) {
        Object (primary_color: primary_color);

        pixels = new Gee.ArrayList<Drawing.Color> ();
        pixels.add (primary_color);
    }

    public int get_dominant_color_index (Gee.List<Drawing.Color> palette) {
        int index = 0;
        var matches = new double[palette.size];

        pixels.foreach ((pixel) => {
            for (int i = 0; i < palette.size; i++) {
                var color = palette.get (i);

                var distance = Math.sqrt (
                    Math.pow ((pixel.R - color.R), 2) +
                    Math.pow ((pixel.G - color.G), 2) +
                    Math.pow ((pixel.B - color.B), 2)
                );

                if (distance > 0.25) {
                    continue;
                }

                matches[i] += 1.0 - distance;
            }

            return true;
        });

        double best_match = double.MIN;
        for (int i = 0; i < matches.length; i++) {
            if (matches[i] > best_match) {
                best_match = matches[i];
                index = i;
            }
        }

        return index;
    }

    private Gee.ArrayList<Drawing.Color> convert_pixels_to_rgb (uint8[] pixels, bool has_alpha) {
        var list = new Gee.ArrayList<Drawing.Color> ();

        int factor = 3 + (int) has_alpha;
        int step_size = (int) (pixels.length / factor * PERCENTAGE_SAMPLE_PIXELS);

        for (int i = 0; i < pixels.length / factor; i += step_size) {
            int offset = i * factor;
            double red = pixels[offset] / 255.0;
            double green = pixels[offset + 1] / 255.0;
            double blue = pixels[offset + 2] / 255.0;

            list.add (new Drawing.Color (red, green, blue, 0.0));
        }

        return list;
    }
}
