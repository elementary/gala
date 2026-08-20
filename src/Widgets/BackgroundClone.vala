/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.BackgroundClone : Clutter.Actor {
    public Meta.Display display { get; construct; }
    public Clutter.Actor background_group { get; construct; }
    public int monitor_index { get; construct; }

    private Clutter.Clone clone;
    private Clutter.Actor clip_actor;

    public BackgroundClone (Meta.Display display, Clutter.Actor background_group, int monitor_index) {
        Object (display: display, background_group: background_group, monitor_index: monitor_index);
    }

    construct {
        clone = new Clutter.Clone (background_group);

        clip_actor = new Clutter.Actor () {
            clip_to_allocation = true,
        };
        clip_actor.add_child (clone);

        add_child (clip_actor);

        display.get_context ().get_backend ().get_monitor_manager ().monitors_changed.connect (update_layout);
        update_layout ();
    }

    private void update_layout () {
        var monitor_geom = display.get_monitor_geometry (monitor_index);
        clip_actor.set_size (monitor_geom.width, monitor_geom.height);

        clone.set_translation (-monitor_geom.x, -monitor_geom.y, 0);
    }
}
