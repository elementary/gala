/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

 public class Gala.WindowListModel : Object, ListModel {
    public enum SortMode {
        NONE,
        STACKING
    }

    public Meta.Display display { get; construct; }

    public SortMode sort_mode { get; construct; }

    /**
     * If true only present windows that are normal as gotten by {@link InternalUtils.get_window_is_normal}.
     */
    public bool normal_filter { get; construct set; }

    /**
     * If >= 0 only present windows that are on this monitor.
     */
    public int monitor_filter { get; construct set; }

    /**
     * If not null only present windows that are on this workspace.
     * This also excludes static windows as defined by {@link StaticWindowContainer.is_static}.
     */
    public Meta.Workspace? workspace_filter { get; construct set; }

    private Gee.ArrayList<Meta.Window> windows;

    public WindowListModel (
        Meta.Display display, SortMode sort_mode = NONE,
        bool normal_filter = false, int monitor_filter = -1,
        Meta.Workspace? workspace_filter = null
    ) {
        Object (
            display: display, sort_mode: sort_mode, normal_filter: normal_filter,
            monitor_filter: monitor_filter, workspace_filter: workspace_filter
        );
    }

    construct {
        windows = new Gee.ArrayList<Meta.Window> ();

        display.window_created.connect (on_window_created);

        WindowListener.get_default ().window_workspace_changed.connect (check_window);

        StaticWindowContainer.get_instance (display).window_changed.connect (check_window);
        display.window_entered_monitor.connect ((monitor, win) => check_window (win));

        notify.connect (check_all);

        check_all ();
    }

    private void on_window_created (Meta.Window window) {
        window.unmanaged.connect ((win) => windows.remove (win));
        check_window (window);
    }

    private void check_all () {
        foreach (var window in display.list_all_windows ()) {
            check_window (window);
        }
    }

    private void check_window (Meta.Window window) {
        var exists = window in windows;
        var should_exist = should_present_window (window);

        if (!exists && should_exist) {
            windows.add (window);
            items_changed (windows.size - 1, 0, 1);
        } else if (exists && !should_exist) {
            var pos = windows.index_of (window);
            windows.remove_at (pos);
            items_changed (pos, 1, 0);
        }
    }

    private bool should_present_window (Meta.Window window) {
        if (monitor_filter >= 0 && monitor_filter != window.get_monitor ()) {
            return false;
        }

        if (workspace_filter != null &&
            (StaticWindowContainer.get_instance (display).is_static (window) ||
            !window.located_on_workspace (workspace_filter))
        ) {
            return false;
        }

        if (normal_filter && !Utils.get_window_is_normal (window)) {
            return false;
        }

        return true;
    }

    public void sort () {
        if (sort_mode == STACKING) {
            var to_sort = new GLib.SList<Meta.Window> ();

            foreach (var window in windows) {
                to_sort.prepend (window);
            }

            var sorted = display.sort_windows_by_stacking (to_sort);

            int i = 0;
            foreach (var window in sorted) {
                windows.set (i++, window);
            }

            items_changed (0, windows.size, windows.size);
        }
    }

    public Object? get_item (uint position) {
        return windows.get ((int) position);
    }

    public uint get_n_items () {
        return windows.size;
    }

    public Type get_item_type () {
        return typeof (Meta.Window);
    }
}
