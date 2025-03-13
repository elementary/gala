//
//  Copyright (C) 2014 Tom Beckmann, Rico Tzschichholz
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

public class Gala.WorkspaceManager : Object {
    public static void init (WindowManager wm) requires (instance == null) {
        instance = new WorkspaceManager (wm);
    }

    public static unowned WorkspaceManager get_default () requires (instance != null) {
        return instance;
    }

    private static WorkspaceManager? instance = null;

    public WindowManager wm { get; construct; }

    private Gee.LinkedList<Meta.Workspace> workspaces_marked_removed;
    private int remove_freeze_count = 0;

    private WorkspaceManager (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        workspaces_marked_removed = new Gee.LinkedList<Meta.Workspace> ();
        unowned Meta.Display display = wm.get_display ();
        unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();

        // There are some empty workspace at startup
        cleanup ();

        manager.override_workspace_layout (Meta.DisplayCorner.TOPLEFT, false, 1, -1);

        for (var i = 0; i < manager.get_n_workspaces (); i++) {
            workspace_added (manager, i);
        }

        manager.workspace_switched.connect_after (workspace_switched);
        manager.workspace_added.connect (workspace_added);
        manager.workspace_removed.connect_after (workspace_removed);
        display.window_entered_monitor.connect (window_entered_monitor);
        display.window_left_monitor.connect (window_left_monitor);

        // make sure the last workspace has no windows on it
        if (Utils.get_n_windows (manager.get_workspace_by_index (manager.get_n_workspaces () - 1)) > 0) {
            append_workspace ();
        }
    }

    ~WorkspaceManager () {
        unowned Meta.Display display = wm.get_display ();
        unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
        manager.workspace_added.disconnect (workspace_added);
        manager.workspace_switched.disconnect (workspace_switched);
        manager.workspace_removed.disconnect (workspace_removed);
        display.window_entered_monitor.disconnect (window_entered_monitor);
        display.window_left_monitor.disconnect (window_left_monitor);
    }

    private void workspace_added (Meta.WorkspaceManager manager, int index) {
        var workspace = manager.get_workspace_by_index (index);
        if (workspace == null) {
            return;
        }

        workspace.window_added.connect (queue_window_added);
        workspace.window_removed.connect (window_removed);
    }

    private void workspace_removed (Meta.WorkspaceManager manager, int index) {
        List<Meta.Workspace> existing_workspaces = null;
        for (int i = 0; i < manager.get_n_workspaces (); i++) {
            existing_workspaces.append (manager.get_workspace_by_index (i));
        }

        var it = workspaces_marked_removed.iterator ();
        while (it.next ()) {
            var workspace = it.@get ();

            if (existing_workspaces.index (workspace) < 0) {
                it.remove ();
            }
        }
    }

    private void workspace_switched (Meta.WorkspaceManager manager, int from, int to, Meta.MotionDirection direction) {
        // remove empty workspaces after we switched away from them
        maybe_remove_workspace (manager.get_workspace_by_index (from), null);
    }

    private void queue_window_added (Meta.Workspace? workspace, Meta.Window window) {
        // We get this call very early so we have to queue an idle for ShellClients
        // that might not have checked the window/got a protocol call yet
        Idle.add (() => window_added (workspace, window));
    }

    private bool window_added (Meta.Workspace? workspace, Meta.Window window) {
        if (workspace == null || window.on_all_workspaces) {
            return Source.REMOVE;
        }

        unowned Meta.WorkspaceManager manager = workspace.get_display ().get_workspace_manager ();
        int last_workspace = manager.get_n_workspaces () - 1;

        if ((window.window_type == Meta.WindowType.NORMAL
            || window.window_type == Meta.WindowType.DIALOG
            || window.window_type == Meta.WindowType.MODAL_DIALOG)
            && workspace.index () == last_workspace
        ) {
            append_workspace ();
        }

        return Source.REMOVE;
    }

    private void window_removed (Meta.Workspace? workspace, Meta.Window window) {
        if (workspace == null || window.on_all_workspaces) {
            return;
        }

        if (window.window_type != Meta.WindowType.NORMAL
            && window.window_type != Meta.WindowType.DIALOG
            && window.window_type != Meta.WindowType.MODAL_DIALOG
        ) {
            return;
        }

        // has already been removed
        if (workspace.index () < 0) {
            return;
        }

        maybe_remove_workspace (workspace, window);
    }

    private void window_entered_monitor (Meta.Display display, int monitor, Meta.Window window) {
        if (Meta.Prefs.get_workspaces_only_on_primary () && monitor == display.get_primary_monitor ()) {
            queue_window_added (window.get_workspace (), window);
        }
    }

    private void window_left_monitor (Meta.Display display, int monitor, Meta.Window window) {
        if (Meta.Prefs.get_workspaces_only_on_primary () && monitor == display.get_primary_monitor ()) {
            window_removed (window.get_workspace (), window);
        }
    }

    private void append_workspace () {
        unowned Meta.Display display = wm.get_display ();
        unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();

        manager.append_new_workspace (false, display.get_current_time ());
    }

    private void maybe_remove_workspace (Meta.Workspace workspace, Meta.Window? window) {
        unowned var manager = workspace.get_display ().get_workspace_manager ();
        var is_active_workspace = workspace == manager.get_active_workspace ();
        var last_workspace_index = manager.get_n_workspaces () - 1 - workspaces_marked_removed.size;

        // remove it right away if it was the active workspace and it's not the very last
        // or we are in modal-mode
        if ((!is_active_workspace || wm.is_modal ())
            && remove_freeze_count < 1
            && Utils.get_n_windows (workspace, true, window) == 0
            && workspace.index () != last_workspace_index
        ) {
            queue_remove_workspace (workspace);
        } else if (is_active_workspace // if window is the second last and empty, make it the last workspace
            && remove_freeze_count < 1
            && Utils.get_n_windows (workspace, true, window) == 0
            && workspace.index () == last_workspace_index - 1
        ) {
            queue_remove_workspace (manager.get_workspace_by_index (last_workspace_index));
        }
    }

    private void queue_remove_workspace (Meta.Workspace workspace) {
        // workspace has already been removed
        if (workspace in workspaces_marked_removed) {
            return;
        }

        workspaces_marked_removed.add (workspace);

        // We might be here because of a signal emition from the ws machinery (e.g. workspace.window_removed).
        // Often the function emitting the signal doesn't take a ref on the ws so if we remove it right
        // away it will be freed. But because the function often accesses it after the singal emition this leads
        // to warnings and in some cases a crash.
        Idle.add (() => remove_workspace (workspace));
    }

    /**
     * Make sure we switch to a different workspace and remove the given one
     *
     * @param workspace The workspace to remove
     */
    private bool remove_workspace (Meta.Workspace workspace) {
        unowned Meta.Display display = workspace.get_display ();
        unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
        var time = display.get_current_time ();
        unowned Meta.Workspace active_workspace = manager.get_active_workspace ();

        if (workspace == active_workspace) {
            Meta.Workspace? next = null;

            next = workspace.get_neighbor (Meta.MotionDirection.LEFT);
            // if it's the first one we may have another one to the right
            if (next == workspace || next == null) {
                next = workspace.get_neighbor (Meta.MotionDirection.RIGHT);
            }

            if (next != null) {
                next.activate (time);
            }
        }

        workspace.window_added.disconnect (queue_window_added);
        workspace.window_removed.disconnect (window_removed);

        manager.remove_workspace (workspace, time);

        return Source.REMOVE;
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
            cleanup ();
        }

        assert (remove_freeze_count >= 0);
    }

    /**
     * If workspaces are dynamic, checks if there are empty workspaces that should
     * be removed. Particularly useful in conjunction with freeze/thaw_remove to
     * cleanup after an operation that required stable workspace/window indices
     */
    private void cleanup () {
        unowned Meta.WorkspaceManager manager = wm.get_display ().get_workspace_manager ();

        bool remove_last = false;
        foreach (var workspace in manager.get_workspaces ().copy ()) {
            if (Utils.get_n_windows (workspace, true) != 0) {
                remove_last = false;
                continue;
            }

            if (workspace.active) {
                remove_last = true;
            } else if (workspace.index () != manager.n_workspaces - 1 || remove_last) {
                remove_workspace (workspace);
            }
        }
    }
}
