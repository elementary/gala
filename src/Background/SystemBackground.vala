/*
 * Copyright 2014 Tom Beckmann
 * Copyright 2023-2024 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.SystemBackground : GLib.Object {
    public Meta.BackgroundActor background_actor { get; construct; }

    public SystemBackground (Meta.Display display) {
        Object (background_actor: new Meta.BackgroundActor (display, 0));
    }

    construct {
        var system_background = new Meta.Background (background_actor.meta_display);
        system_background.set_color ({ 0x2e, 0x34, 0x36, 0xff });

        ((Meta.BackgroundContent) background_actor.content).background = system_background;
    }
}
