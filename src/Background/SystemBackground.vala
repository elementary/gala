/*
 * Copyright 2014 Tom Beckmann
 * Copyright 2023-2024 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.SystemBackground : GLib.Object {
    public Meta.BackgroundActor background_actor { get; construct; }

    private Meta.Background system_background;

    public SystemBackground (Meta.Display display) {
        Object (background_actor: new Meta.BackgroundActor (display, 0));
    }

    construct {
        system_background = new Meta.Background (background_actor.meta_display);
        ((Meta.BackgroundContent) background_actor.content).background = system_background;

        set_black_background (true);
    }

    public void set_black_background (bool black) {
        var color = black ? Clutter.Color ().init( 0, 0, 0, 0xff) : Clutter.Color ().init (0x2e, 0x34, 0x36, 0xff);
        system_background.set_color (color);
    }
}
