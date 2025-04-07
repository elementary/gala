/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WorkspaceRow : ActorTarget {
    public const int WORKSPACE_GAP = 24;

    public signal void window_selected (Meta.Window window);

    public WindowManager wm { get; construct; }

    public float scale_factor { get; construct set; }

    public WorkspaceRow (WindowManager wm, float scale_factor) {
        Object (wm: wm, scale_factor: scale_factor);
    }

    construct {
        unowned var manager = WorkspaceManager.get_default ();
        bind_model (manager.workspaces, create_child_func);
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

    private Clutter.Actor create_child_func (Object item) {
        var workspace_clone = new WorkspaceClone (wm, (Meta.Workspace) item, scale_factor);
        bind_property ("scale-factor", workspace_clone, "scale-factor");
        workspace_clone.window_selected.connect ((window) => window_selected (window));
        return workspace_clone;
    }
}
