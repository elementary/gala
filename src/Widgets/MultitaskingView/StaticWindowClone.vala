/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * A exact clone of a window (same position and size). This is used for static
 * windows (e.g. on all workspaces or moving) and fades out while the multitasking view
 * is being opened.
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

        set_pivot_point (0.5f, 0.5f);

        add_target (new PropertyTarget (MULTITASKING_VIEW, this, "opacity", typeof (uint), 255u, 0u));

        window_actor.bind_property ("x", this, "x", SYNC_CREATE);
        window_actor.bind_property ("y", this, "y", SYNC_CREATE);
    }

    public override void update_progress (Gala.GestureAction action, double progress) {
        if (action == SWITCH_WORKSPACE) {
            var multiplier = (((int) progress) - progress).abs ();
            var scale = multiplier * 0.2 + 0.8;
            set_scale (scale, scale);
        }
    }

    public override void end_progress (Gala.GestureAction action) {
        if (action == SWITCH_WORKSPACE) {
            set_scale (1.0, 1.0);
        }
    }
}
