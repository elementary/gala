/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2014 Tom Beckmann
 *                         2025 elementary, Inc. (https://elementary.io)
 */

/**
 * More or less utility class to contain a WindowCloneContainer for each
 * non-primary monitor. It's the pendant to the WorkspaceClone which is
 * only placed on the primary monitor. It also draws a wallpaper behind itself
 * as the WindowGroup is hidden while the view is active. Only used when
 * workspaces-only-on-primary is set to true.
 */
public class Gala.MonitorClone : ActorTarget {
    public signal void window_selected (Meta.Window window);

    public WindowManager wm { get; construct; }
    public int monitor { get; construct; }

    private WindowCloneContainer window_container;
    private BackgroundManager background;

    public MonitorClone (WindowManager wm, int monitor) {
        Object (wm: wm, monitor: monitor);
    }

    construct {
        reactive = true;

        unowned var display = wm.get_display ();

        background = new BackgroundManager (display, monitor, false);

        var scale = display.get_monitor_scale (monitor);

        window_container = new WindowCloneContainer (wm, scale);
        window_container.window_selected.connect ((w) => { window_selected (w); });

        display.window_entered_monitor.connect (window_entered);
        display.window_left_monitor.connect (window_left);

        unowned GLib.List<Meta.WindowActor> window_actors = display.get_window_actors ();
        foreach (unowned Meta.WindowActor window_actor in window_actors) {
            if (window_actor.is_destroyed ())
                continue;

            unowned Meta.Window window = window_actor.get_meta_window ();
            if (window.get_monitor () == monitor) {
                window_entered (monitor, window);
            }
        }

        add_child (background);
        add_child (window_container);

        var drop = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
        add_action (drop);

        update_allocation ();
    }

    ~MonitorClone () {
        unowned var display = wm.get_display ();
        display.window_entered_monitor.disconnect (window_entered);
        display.window_left_monitor.disconnect (window_left);
    }

    /**
     * Make sure the MonitorClone is at the location of the monitor on the stage
     */
    public void update_allocation () {
        unowned var display = wm.get_display ();

        var monitor_geometry = display.get_monitor_geometry (monitor);

        set_position (monitor_geometry.x, monitor_geometry.y);
        set_size (monitor_geometry.width, monitor_geometry.height);
        window_container.set_size (monitor_geometry.width, monitor_geometry.height);

        var scale = display.get_monitor_scale (monitor);
        window_container.monitor_scale = scale;
    }

    private void window_left (int window_monitor, Meta.Window window) {
        if (window_monitor != monitor)
            return;

        window_container.remove_window (window);
    }

    private void window_entered (int window_monitor, Meta.Window window) {
        if (window_monitor != monitor || window.window_type != Meta.WindowType.NORMAL)
            return;

        window_container.add_window (window);
    }
}
