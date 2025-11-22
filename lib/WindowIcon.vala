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
        /**
         * Sometimes a WindowIcon is constructed on Meta.Display::window_created.
         * In this case it can happen that we don't have any info about the app yet so we can't get the
         * correct icon. Therefore we check whether the info becomes available at some point
         * and if it does we try to get a new icon.
         */
        window.notify["wm-class"].connect (reload_icon);
        window.notify["gtk-application-id"].connect (reload_icon);

        reload_icon ();
        resource_scale_changed.connect (reload_icon);
    }

    private void reload_icon () {
        var actor_size = icon_size * scale;

        width = actor_size;
        height = actor_size;

        var pixbuf_size = (int) Math.ceilf (actor_size * get_resource_scale ());

        var pixbuf = Gala.Utils.get_icon_for_window (window, pixbuf_size, 1);
        var image = new Gala.Image.from_pixbuf_with_size (actor_size, actor_size, pixbuf);
        set_content (image);
    }
}
