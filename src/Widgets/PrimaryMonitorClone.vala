/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PrimaryMonitorClone : ActorTarget {
    public const string GESTURE_ID = "workspace-row";

    public Meta.Display display { get; construct; }

    public IconGroupContainer icon_groups { get; construct; }
    public ActorTarget workspaces { get; construct; }

    public PrimaryMonitorClone (Meta.Display display, IconGroupContainer icon_groups, ActorTarget workspaces) {
        Object (display: display, icon_groups: icon_groups, workspaces: workspaces);
    }

    construct {
        add_child (icon_groups);
        add_child (workspaces);
    }

    public override void allocate (Clutter.ActorBox allocation) {
        set_allocation (allocation);

        float workspaces_x = (float) (get_current_progress (GESTURE_ID) * workspaces.get_first_child ().width);
        workspaces.allocate_preferred_size (Math.roundf (workspaces_x), 0);

        var scale = display.get_monitor_scale (display.get_primary_monitor ());
        float icon_groups_y = allocation.get_height () - InternalUtils.scale_to_int (WorkspaceClone.BOTTOM_OFFSET - 20, scale);

        float icon_groups_x, icon_groups_width;
        icon_groups.get_preferred_width (-1, null, out icon_groups_width);
        if (icon_groups_width <= allocation.get_width ()) {
            icon_groups_x = allocation.get_width () / 2 - icon_groups_width / 2;
        } else {
            icon_groups_x = (float) (get_current_progress (GESTURE_ID) * InternalUtils.scale_to_int (IconGroupContainer.SPACING + IconGroup.SIZE, scale) + allocation.get_width () / 2)
                .clamp (allocation.get_width () - icon_groups_width - InternalUtils.scale_to_int (64, scale), InternalUtils.scale_to_int (64, scale));
        }

        icon_groups.allocate_preferred_size (Math.roundf (icon_groups_x), Math.roundf (icon_groups_y));
    }

    public override void update_progress (string id, double progress) {
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
}
