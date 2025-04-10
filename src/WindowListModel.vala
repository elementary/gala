/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

//filter by ws, monitor, normal
public class Gala.WindowListModel : Object, ListModel {
    public WindowManagerGala wm { get; construct; }

    /**
     * If > 0 only present windows that are on this monitor.
     */
    public int monitor_filter { get; set; default = -1; }

    /**
     * If not null only present windows that are on this workspace.
     */
    public Meta.Workspace? workspace_filter { get; set; default = null; }

    /**
     * If true only present windows that are normal as gotten by {@link InternalUtils.get_window_is_normal}.
     */
    public bool normal_filter { get; set; default = false; }

    private ListStore windows;
    private Gee.TreeSet<uint> tree_set;

    public WindowListModel (WindowManagerGala wm) {
        Object (wm: wm);
    }

    construct {
        windows = wm.windows;
        tree_set = new Gee.TreeSet<uint> ();

        windows.items_changed.connect (on_items_changed);
        on_items_changed (0, 0, windows.n_items);

        WindowListener.get_default ().window_workspace_changed.connect (refilter_window);
        wm.get_display ().window_entered_monitor.connect ((monitor, win) => refilter_window (win));

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
            items_changed (pos_filtered, removed_filtered, added_filtered);
        }
    }

    private bool should_present_window (Meta.Window window) {
        if (monitor_filter >= 0 && monitor_filter != window.get_monitor ()) {
            return false;
        }

        if (workspace_filter != null && (window.on_all_workspaces || !window.located_on_workspace (workspace_filter))) {
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

    public Object? get_item (uint position) {
        uint current_pos = 0;
        var iter = tree_set.iterator ();
        while (iter.next ()) {
            if (current_pos == position) {
                return windows.get_item (iter.get ());
            }
            current_pos++;
        }

        return null;
    }

    public uint get_n_items () {
        return tree_set.size;
    }

    public Type get_item_type () {
        return typeof (Meta.Window);
    }
}
