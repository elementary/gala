/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.StaticWindowClone : ActorTarget {
    public Meta.Window window { get; construct; }

    public StaticWindowClone (Meta.Window window) {
        Object (window: window);
    }

    construct {
        var window_actor = (Meta.WindowActor) window.get_compositor_private ();
        var clone = new Clutter.Clone (window_actor);
        add_child (clone);

        add_target (new PropertyTarget (MULTITASKING_VIEW, this, "opacity", typeof (uint), 255u, 0u));

        window_actor.bind_property ("x", this, "x", SYNC_CREATE);
        window_actor.bind_property ("y", this, "y", SYNC_CREATE);
    }
}
