/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WorkspaceRow : ActorTarget {
    public const int WORKSPACE_GAP = 24;

    public WindowManager wm { get; construct; }
    public float monitor_scale { get; construct set; }
    public IconGroupContainer icon_groups { get; construct; }

    public WorkspaceRow (WindowManager wm, float monitor_scale) {
        Object (wm: wm, monitor_scale: monitor_scale);
    }

    construct {
        icon_groups = new IconGroupContainer (monitor_scale);

        unowned var manager = wm.get_display ().get_workspace_manager ();
        manager.workspace_added.connect (add_workspace);
        manager.workspace_removed.connect (remove_workspace);
        manager.workspaces_reordered.connect (update_order);

        for (int i = 0; i < manager.get_n_workspaces (); i++) {
            add_workspace (i);
        }
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

    private void add_workspace (int index) {
        unowned var manager = wm.get_display ().get_workspace_manager ();
        unowned var workspace = manager.get_workspace_by_index (index);

        var workspace_clone = new WorkspaceClone (wm, workspace, monitor_scale);
        bind_property ("monitor-scale", workspace_clone, "monitor-scale");

        insert_child_at_index (workspace_clone, index);

        icon_groups.add_group (workspace_clone.icon_group);
    }

    private void remove_workspace (int index) {
        var workspace_clone = (WorkspaceClone) get_child_at_index (index);
        remove_child (workspace_clone);

        icon_groups.remove_group (workspace_clone.icon_group);
    }

    private void update_order () {
        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            unowned var workspace_clone = (WorkspaceClone) child;
            set_child_at_index (workspace_clone, workspace_clone.workspace.index ());
        }
    }
}
