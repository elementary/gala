/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WorkspaceRow : ActorTarget {
    public const string GESTURE_ID = "workspace-row";

    public Meta.Display display { get; construct; }

    public WorkspaceRow (Meta.Display display) {
        Object (display: display);
    }

    construct {
        layout_manager = new Clutter.BoxLayout ();
        notify["width"].connect (update_x);

        unowned var manager = display.get_workspace_manager ();
        manager.workspaces_reordered.connect (update_order);
    }

    private void update_order () {
        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            unowned var workspace_clone = (WorkspaceClone) child;
            set_child_at_index (workspace_clone, workspace_clone.workspace.index ());
        }
    }

    private void update_x () {
        x = (float) get_current_progress (GESTURE_ID) * get_first_child ().width;
    }

    public override void update_progress (string id, double progress) {
        if (id == GESTURE_ID) {
            update_x ();
        }
    }

    public override void commit_progress (string id, double to) {
        if (id != GESTURE_ID) {
            return;
        }

        unowned var workspace_manager = display.get_workspace_manager ();
        workspace_manager.get_workspace_by_index ((int) (-to)).activate (display.get_current_time ());
    }
}
