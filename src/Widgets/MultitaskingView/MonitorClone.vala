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
    public float monitor_scale { get; construct set; }

    private WindowCloneContainer window_container;
    private BackgroundManager background;

    public MonitorClone (WindowManager wm, int monitor) {
        Object (wm: wm, monitor: monitor);
    }

    construct {
        reactive = true;
        update_allocation ();

        unowned var display = wm.get_display ();

        background = new BackgroundManager (display, monitor, false);

        var windows = new WindowListModel (display, STACKING, true, monitor);

        window_container = new WindowCloneContainer (wm, windows);
        window_container.add_constraint (new Clutter.BindConstraint (this, SIZE, 0.0f));
        window_container.window_selected.connect ((w) => { window_selected (w); });

        add_child (background);
        add_child (window_container);

        var drop = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
        add_action (drop);
    }

    /**
     * Make sure the MonitorClone is at the location of the monitor on the stage
     */
    public void update_allocation () {
        unowned var display = wm.get_display ();

        var monitor_geometry = display.get_monitor_geometry (monitor);

        set_position (monitor_geometry.x, monitor_geometry.y);
        set_size (monitor_geometry.width, monitor_geometry.height);

        monitor_scale = display.get_monitor_scale (monitor);
    }
}
