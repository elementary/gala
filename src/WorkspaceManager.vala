/*
 * Copyright 2014 Tom Beckmann, Rico Tzschichholz
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WorkspaceManager : Object {
    public static void init (WindowManager wm) requires (instance == null) {
        instance = new WorkspaceManager (wm);
    }

    public static unowned WorkspaceManager get_default () requires (instance != null) {
        return instance;
    }

    private static WorkspaceManager? instance = null;

    public WindowManager wm { get; construct; }

    private int remove_freeze_count = 0;
    private uint check_workspaces_id = 0;

    private WorkspaceManager (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        unowned var display = wm.get_display ();
        unowned var manager = display.get_workspace_manager ();

        manager.override_workspace_layout (Meta.DisplayCorner.TOPLEFT, false, 1, -1);

        for (var i = 0; i < manager.get_n_workspaces (); i++) {
            workspace_added (manager, i);
        }

        manager.workspace_switched.connect_after (queue_check_workspaces);
        manager.workspace_added.connect (workspace_added);
        display.window_entered_monitor.connect (window_entered_monitor);
        display.window_left_monitor.connect (window_left_monitor);
    }

    private void workspace_added (Meta.WorkspaceManager manager, int index) {
        var workspace = manager.get_workspace_by_index (index);
        if (workspace == null) {
            return;
        }

        workspace.window_added.connect (queue_check_workspaces);
        workspace.window_removed.connect (queue_check_workspaces);
    }

    private void window_entered_monitor (Meta.Display display, int monitor, Meta.Window window) {
        if (Meta.Prefs.get_workspaces_only_on_primary () && monitor == display.get_primary_monitor ()) {
            queue_check_workspaces ();
        }
    }

    private void window_left_monitor (Meta.Display display, int monitor, Meta.Window window) {
        if (Meta.Prefs.get_workspaces_only_on_primary () && monitor == display.get_primary_monitor ()) {
            queue_check_workspaces ();
        }
    }

    /**
     * Temporarily disables removing workspaces when they are empty
     */
    public void freeze_remove () {
        GLib.AtomicInt.inc (ref remove_freeze_count);
    }

    /**
     * Undo the effect of freeze_remove()
     */
    public void thaw_remove () {
        if (GLib.AtomicInt.dec_and_test (ref remove_freeze_count)) {
            queue_check_workspaces ();
        }

        assert (remove_freeze_count >= 0);
    }

    private void queue_check_workspaces () {
        if (check_workspaces_id == 0) {
            var laters = wm.get_display ().get_compositor ().get_laters ();
            check_workspaces_id = laters.add (BEFORE_REDRAW, check_workspaces);
        }
    }

    private bool check_workspaces () {
        unowned var display = wm.get_display ();
        unowned var manager = display.get_workspace_manager ();

        if (remove_freeze_count > 0) {
            return Source.CONTINUE;
        }

        bool[] empty_workspaces = new bool[manager.n_workspaces];

        for (int i = 0; i < empty_workspaces.length; i++) {
            empty_workspaces[i] = true;
        }

        unowned var active_startup_sequences = display.get_startup_notification ().get_sequences ();
        foreach (var startup_sequence in active_startup_sequences) {
            var index = startup_sequence.get_workspace ();
            if (index >= 0 && index < empty_workspaces.length) {
                empty_workspaces[index] = false;
            }
        }

#if HAS_MUTTER48
        unowned var window_actors = display.get_compositor ().get_window_actors ();
#else
        unowned var window_actors = display.get_window_actors ();
#endif
        foreach (var actor in window_actors) {
            var win = actor.meta_window;

            if (win == null ||
                win.on_all_workspaces ||
                win.get_workspace () == null ||
                !Utils.get_window_and_ancestors_normal (win)
            ) {
                continue;
            }

            empty_workspaces[win.get_workspace ().index ()] = false;
        }

        // If we don't have an empty workspace at the end, add one
        if (!empty_workspaces[empty_workspaces.length - 1]) {
            manager.append_new_workspace (false, display.get_current_time ());
            empty_workspaces += true;
        }

        var last_index = empty_workspaces.length - 1;

        int last_empty_index = 0;
        for (int i = last_index; i >= 0; i--) {
            if (!empty_workspaces[i]) {
                last_empty_index = i + 1;
                break;
            }
        }

        if (!wm.is_modal ()) {
            var active_index = manager.get_active_workspace_index ();
            empty_workspaces[active_index] = false;
        }

        // Delete empty workspaces except for the last one; do it from the end
        // to avoid index changes
        for (int i = last_index; i >= 0; i--) {
            if (!empty_workspaces[i] || i == last_empty_index) {
                continue;
            }

            var workspace = manager.get_workspace_by_index (i);

            if (workspace == manager.get_active_workspace ()) {
                Meta.Workspace? next = null;

                next = workspace.get_neighbor (LEFT);
                // If it's the first one we may have another one to the right
                if (next == workspace || next == null) {
                    next = workspace.get_neighbor (RIGHT);
                }

                if (next != null) {
                    next.activate (display.get_current_time ());
                }
            }

            manager.remove_workspace (workspace, display.get_current_time ());
        }

        check_workspaces_id = 0;
        return Source.REMOVE;
    }
}
