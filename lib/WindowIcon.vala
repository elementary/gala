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
    public float monitor_scale { get; construct set; }

    /**
     * Creates a new WindowIcon
     *
     * @param window               The window for which to create the icon
     * @param icon_size            The size of the icon in pixels
     * @param monitor_scale        The desired scale of the icon
     */
    public WindowIcon (Meta.Window window, int icon_size, float monitor_scale) {
        Object (window: window, icon_size: icon_size, monitor_scale: monitor_scale);
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

        notify["monitor-scale"].connect (reload_icon);

        reload_icon ();
    }

    private void reload_icon () {
        var actual_size = Utils.scale_to_int (icon_size, monitor_scale);

        width = actual_size;
        height = actual_size;

        var pixbuf = Gala.Utils.get_icon_for_window (window, actual_size, 1);
        var image = new Gala.Image.from_pixbuf (pixbuf);
        set_content (image);
    }
}
