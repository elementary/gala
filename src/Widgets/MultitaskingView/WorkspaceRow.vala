/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WorkspaceRow : ActorTarget {
    public const int WORKSPACE_GAP = 24;

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

        double progress = get_current_progress (SWITCH_WORKSPACE);
        int index = 0;
        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            float preferred_width;
            child.get_preferred_width (-1, null, out preferred_width);

            var child_x = (float) Math.round ((progress + index) * (preferred_width + WORKSPACE_GAP));

            child.allocate_preferred_size (child_x, 0);

            index++;
        }
    }

    public override void update_progress (GestureAction action, double to) {
        if (action == SWITCH_WORKSPACE) {
            queue_relayout ();
        }
    }

    public override bool move_focus (FocusDirection direction) {
        var focusable = (Focusable) get_child_at_index ((int) (-get_current_commit (SWITCH_WORKSPACE)));
        return focusable.focus (direction);
    }

    private void update_order () {
        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            unowned var workspace_clone = (WorkspaceClone) child;
            set_child_at_index (workspace_clone, workspace_clone.workspace.index ());
        }
    }
}
