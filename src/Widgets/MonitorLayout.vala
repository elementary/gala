/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.MonitorLayout : Clutter.LayoutManager {
    public Meta.Display display { get; construct; }

    private float width;
    private float height;

    public MonitorLayout (Meta.Display display) {
        Object (display: display);
    }

    construct {
        unowned var manager = display.get_context ().get_backend ().get_monitor_manager ();
        manager.monitors_changed.connect (on_monitors_changed);
        on_monitors_changed ();
    }

    private void on_monitors_changed () {
        width = 0;
        height = 0;

        for (int i = 0; i < display.get_n_monitors (); i++) {
            var monitor_geom = display.get_monitor_geometry (i);
            width = float.max (width, monitor_geom.x + monitor_geom.width);
            height = float.max (height, monitor_geom.y + monitor_geom.height);
        }

        layout_changed ();
    }

    public override void allocate (Clutter.Actor container, Clutter.ActorBox allocation) {
        int monitor_index = 0;
        for (var child = container.get_first_child (); child != null; child = child.get_next_sibling ()) {
            var monitor_geom = display.get_monitor_geometry (monitor_index);

            var child_alloc = InternalUtils.actor_box_from_rect (
                monitor_geom.x , monitor_geom.y,
                monitor_geom.width, monitor_geom.height
            );

            child.allocate (child_alloc);

            monitor_index++;
        }
    }

    public override void get_preferred_width (Clutter.Actor container, float for_height, out float min_width, out float nat_width) {
        nat_width = min_width = width;
    }

    public override void get_preferred_height (Clutter.Actor container, float for_width, out float min_height, out float nat_height) {
        nat_height = min_height = height;
    }
}
