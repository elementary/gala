/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WindowListModel : Object, ListModel {
    public enum SortMode {
        NONE,
        STACKING
    }

    public WindowManager wm { get; construct; }

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

    private ListStore windows;
    private Gee.TreeSet<uint> tree_set;
    private Gee.ArrayList<uint> sorted;

    public WindowListModel (
        WindowManager wm, SortMode sort_mode = NONE,
        bool normal_filter = false, int monitor_filter = -1,
        Meta.Workspace? workspace_filter = null
    ) {
        Object (
            wm: wm, sort_mode: sort_mode, normal_filter: normal_filter,
            monitor_filter: monitor_filter, workspace_filter: workspace_filter
        );
    }

    construct {
        windows = wm.windows;
        tree_set = new Gee.TreeSet<uint> ();
        sorted = new Gee.ArrayList<uint> ();

        windows.items_changed.connect (on_items_changed);
        on_items_changed (0, 0, windows.n_items);

        WindowListener.get_default ().window_workspace_changed.connect (refilter_window);

        unowned var display = wm.get_display ();
        StaticWindowContainer.get_instance (display).window_changed.connect (refilter_window);
        display.window_entered_monitor.connect ((monitor, win) => refilter_window (win));

        notify.connect (() => on_items_changed (0, windows.n_items, windows.n_items));
    }

    private void on_items_changed (uint pos, uint removed, uint added) {
        uint pos_filtered = 0;
        uint removed_filtered = 0;
        uint added_filtered = 0;

        var iter = tree_set.iterator ();
        while (iter.next () && iter.get () < pos) {
            pos_filtered++;
        }

        for (uint i = pos; i < pos + removed; i++) {
            if (tree_set.remove (i)) {
                removed_filtered++;
            }
        }

        // => [pos, pos + removed) NOT in tree_set

        // Now we shift the tail behind and including pos by the changed position
        var new_tail = new Gee.TreeSet<uint> ();
        for (uint i = pos; !tree_set.is_empty && i <= tree_set.last (); i++) {
            if (tree_set.remove (i)) {
                new_tail.add (i + (added - removed));
            }
        }

        tree_set.add_all (new_tail);

        // => [pos, pos + added) NOT in tree_set AND windows.get_item (i) = same as before changed FOR ALL i in tree_set

        for (uint i = pos; i < pos + added; i++) {
            var window = (Meta.Window) windows.get_item (i);
            if (should_present_window (window)) {
                tree_set.add (i);
                added_filtered++;
            }
        }

        // => tree_set fully valid

        if (removed_filtered != 0 || added_filtered != 0) {
            var removed_sorted = sorted.size;

            sorted.clear ();
            sorted.add_all (tree_set);

            if (sort_mode == STACKING) {
                sorted.sort (stacking_sort_func);
                items_changed (0, removed_sorted, sorted.size);
            } else {
                items_changed (pos_filtered, removed_filtered, added_filtered);
            }
        }
    }

    private bool should_present_window (Meta.Window window) {
        if (monitor_filter >= 0 && monitor_filter != window.get_monitor ()) {
            return false;
        }

        if (workspace_filter != null &&
            (StaticWindowContainer.get_instance (wm.get_display ()).is_static (window) ||
            !window.located_on_workspace (workspace_filter))
        ) {
            return false;
        }

        if (normal_filter && !InternalUtils.get_window_is_normal (window)) {
            return false;
        }

        return true;
    }

    private void refilter_window (Meta.Window window) {
        uint pos;
        if (windows.find (window, out pos)) {
            on_items_changed (pos, 1, 1);
        }
    }

    public void resort () {
        if (sort_mode == STACKING) {
            sorted.sort (stacking_sort_func);
            items_changed (0, sorted.size, sorted.size);
        }
    }

    public Object? get_item (uint position) {
        return windows.get_item (sorted.get ((int) position));
    }

    public uint get_n_items () {
        return tree_set.size;
    }

    public Type get_item_type () {
        return typeof (Meta.Window);
    }

    private int stacking_sort_func (uint a, uint b) {
        var window_a = (Meta.Window) windows.get_item (a);
        var window_b = (Meta.Window) windows.get_item (b);

        return (int) window_a.user_time - (int) window_b.user_time;
    }
}
