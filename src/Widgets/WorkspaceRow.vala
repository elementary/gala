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
        unowned var manager = display.get_workspace_manager ();
        manager.workspaces_reordered.connect (update_order);
    }

    public override void allocate (Clutter.ActorBox allocation) {
        set_allocation (allocation);

        double progress = get_current_progress (GESTURE_ID);
        int index = 0;
        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            float preferred_width;
            child.get_preferred_width (-1, null, out preferred_width);

            var child_x = (float) Math.round ((progress + index) * preferred_width);

            child.allocate_preferred_size (child_x, 0);

            index++;
        }
    }

    public override void update_progress (string id, double to) {
        if (id == GESTURE_ID) {
            queue_relayout ();
        }
    }

    public override void commit_progress (string id, double to) {
        if (id == GESTURE_ID) {
            unowned var workspace_manager = display.get_workspace_manager ();
            workspace_manager.get_workspace_by_index ((int) (-to)).activate (display.get_current_time ());
        }
    }

    private void update_order () {
        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            unowned var workspace_clone = (WorkspaceClone) child;
            set_child_at_index (workspace_clone, workspace_clone.workspace.index ());
        }
    }
}
