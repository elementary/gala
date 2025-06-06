/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2014 Tom Beckmann
 *                         2025 elementary, Inc. <https://elementary.io>
 */

/**
 * This class contains the icon groups at the bottom and will take
 * care of displaying actors for inserting windows between the groups
 * once implemented
 */
public class Gala.IconGroupContainer : Clutter.Actor {
    public const int SPACING = 48;
    public const int GROUP_WIDTH = 64;

    public signal void request_reposition (bool animate);

    private float _scale_factor = 1.0f;
    public float scale_factor {
        get {
            return _scale_factor;
        }
        set {
            if (value != _scale_factor) {
                _scale_factor = value;
                reallocate ();
            }
        }
    }

    public IconGroupContainer (float scale) {
        Object (scale_factor: scale);

        layout_manager = new Clutter.BoxLayout ();
    }

    private void reallocate () {
        foreach (var child in get_children ()) {
            unowned WorkspaceInsertThumb thumb = child as WorkspaceInsertThumb;
            if (thumb != null) {
                thumb.scale_factor = scale_factor;
            }
        }
    }

    public void add_group (IconGroup group) {
        var index = group.workspace.index ();

        insert_child_at_index (group, index * 2);

        var thumb = new WorkspaceInsertThumb (index, scale_factor);
        thumb.notify["expanded"].connect_after (expanded_changed);
        insert_child_at_index (thumb, index * 2);

        update_inserter_indices ();
    }

    public void remove_group (IconGroup group) {
        var thumb = (WorkspaceInsertThumb) group.get_previous_sibling ();
        thumb.notify["expanded"].disconnect (expanded_changed);
        remove_child (thumb);

        remove_child (group);

        update_inserter_indices ();
    }

    /**
     * Removes an icon group "in place".
     * When initially dragging an icon group we remove
     * it and it's previous WorkspaceInsertThumb. This would make
     * the container immediately reallocate and fill the empty space
     * with right-most IconGroups.
     *
     * We don't want that until the IconGroup
     * leaves the expanded WorkspaceInsertThumb.
     */
    public void remove_group_in_place (IconGroup group) {
        var deleted_thumb = (WorkspaceInsertThumb) group.get_previous_sibling ();
        var deleted_placeholder_thumb = (WorkspaceInsertThumb) group.get_next_sibling ();

        remove_group (group);

        /*
        * We will account for that empty space
        * by manually expanding the next WorkspaceInsertThumb with the
        * width we deleted. Because the IconGroup is still hovering over
        * the expanded thumb, we will also update the drag & drop action
        * of IconGroup on that.
        */
        if (deleted_placeholder_thumb != null) {
            float deleted_width = deleted_thumb.get_width () + group.get_width ();
            deleted_placeholder_thumb.expanded = true;
            deleted_placeholder_thumb.width += deleted_width;
            group.set_hovered_actor (deleted_placeholder_thumb);
        }
    }

    public void reset_thumbs (int delay) {
        foreach (var child in get_children ()) {
            unowned WorkspaceInsertThumb thumb = child as WorkspaceInsertThumb;
            if (thumb != null) {
                thumb.delay = delay;
                thumb.destroy_all_children ();
            }
        }
    }

    private void expanded_changed (ParamSpec param) {
        request_reposition (true);
    }

    /**
     * Calculates the width that will be occupied taking currently running animations
     * end states into account
     */
    public float calculate_total_width () {
        var spacing = Utils.scale_to_int (SPACING, scale_factor);
        var group_width = Utils.scale_to_int (GROUP_WIDTH, scale_factor);

        var width = 0.0f;
        foreach (var child in get_children ()) {
            if (child is WorkspaceInsertThumb) {
                if (((WorkspaceInsertThumb) child).expanded)
                    width += group_width + spacing * 2;
                else
                    width += spacing;
            } else
                width += group_width;
        }

        width += spacing;

        return width;
    }

    public void force_reposition () {
        var children = get_children ();

        foreach (var child in children) {
            if (child is IconGroup) {
                remove_group ((IconGroup) child);
            }
        }

        foreach (var child in children) {
            if (child is IconGroup) {
                add_group ((IconGroup) child);
            }
        }
    }

    private void update_inserter_indices () {
        var current_index = 0;

        foreach (var child in get_children ()) {
            unowned WorkspaceInsertThumb thumb = child as WorkspaceInsertThumb;
            if (thumb != null) {
                thumb.workspace_index = current_index++;
            }
        }
    }
}
