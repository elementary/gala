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

public class Gala.NamedColor : Object {
    public string theme { get; set; }
    public string name { get; set; }
    public string hex { get; set; }

    public NamedColor.from_rgba (Gdk.RGBA rgba) {
        hex = "#%02x%02x%02x".printf (
            (int) (rgba.red * 255),
            (int) (rgba.green * 255),
            (int) (rgba.blue * 255)
        );
    }

    public double compare (NamedColor other) {
        var rgba1 = to_rgba ();
        var rgba2 = other.to_rgba ();

        var distance = Math.sqrt (
            Math.pow ((rgba2.red - rgba1.red), 2) +
            Math.pow ((rgba2.green - rgba1.green), 2) +
            Math.pow ((rgba2.blue - rgba1.blue), 2)
        );

        return 1.0 - distance / Math.sqrt (
            Math.pow (255, 2) +
            Math.pow (255, 2) +
            Math.pow (255, 2)
        );
    }

    public Gdk.RGBA to_rgba () {
        Gdk.RGBA rgba = { 0, 0, 0, 0 };
        rgba.parse (hex);

        return rgba;
    }
}
