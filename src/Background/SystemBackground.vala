/*
 * Copyright 2014 Tom Beckmann
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.SystemBackground : GLib.Object {
    private const Clutter.Color DEFAULT_BACKGROUND_COLOR = { 0x2e, 0x34, 0x36, 0xff };

    public Meta.BackgroundActor background_actor { get; construct; }

    private static Meta.Background? system_background = null;

    public SystemBackground (Meta.Display display) {
        Object (background_actor: new Meta.BackgroundActor (display, 0));
    }

    construct {
        if (system_background == null) {
            system_background = new Meta.Background (background_actor.meta_display);
            system_background.set_color (DEFAULT_BACKGROUND_COLOR);
        }

        ((Meta.BackgroundContent) background_actor.content).background = system_background;
    }

    public static void refresh () {
        // Meta.Background.refresh_all does not refresh backgrounds with the WALLPAPER style.
        // (Last tested with mutter 3.28)
        // As a workaround, re-apply the current color again to force the wallpaper texture
        // to be rendered from scratch.
        if (system_background != null) {
            system_background.set_color (DEFAULT_BACKGROUND_COLOR);
        }
    }
}
