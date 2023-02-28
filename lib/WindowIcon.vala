/*
 * Copyright 2012 Tom Beckmann
 * Copyright 2012 Rico Tzschichholz
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * Creates a new ClutterTexture with an icon for the window at the given size.
 * This is recommended way to grab an icon for a window as this method will make
 * sure the icon is updated if it becomes available at a later point.
 */
public class Gala.WindowIcon : Clutter.Actor {
    public Meta.Window window { get; construct; }
    public int icon_size { get; construct; }
    public int scale { get; construct; }

    /**
     * Creates a new WindowIcon
     *
     * @param window               The window for which to create the icon
     * @param icon_size            The size of the icon in pixels
     * @param scale                The desired scale of the icon
     */
    public WindowIcon (Meta.Window window, int icon_size, int scale = 1) {
        Object (window: window,
            icon_size: icon_size,
            scale: scale);
    }

    construct {
        width = icon_size * scale;
        height = icon_size * scale;

        var pixbuf = Gala.Utils.get_icon_for_window (window, icon_size, scale);
        try {
            var image = new Clutter.Image ();
            Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
            image.set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);
            set_content (image);
        } catch (Error e) {}
    }
}
