/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Focusable : Clutter.Actor {
    public bool can_focus { get; set; default = false; }
    public bool has_visible_focus { get; private set; default = false; }

    construct {
        key_focus_in.connect (focus_changed);
        key_focus_out.connect (focus_changed);
    }

    internal void focus_changed () {
        has_visible_focus = has_key_focus () && get_root ().get_qdata<bool> (FocusController.focus_visible_quark);
    }

    private Focusable get_root () {
        var parent = get_parent ();
        if (parent is Focusable) {
            return parent.get_root ();
        }

        return this;
    }

    public bool focus (FocusDirection direction) {
        var focus_actor = get_stage ().get_key_focus ();

        // We have focus so try to move it to a child
        if (focus_actor == this) {
            if (direction.is_forward ()) {
                return move_focus (direction);
            }

            return false;
        }

        // A child of us (or subchild) has focus, try to move it to the next one.
        // If that doesn't work and we are moving backwards focus us
        if (focus_actor != null && focus_actor is Focusable && focus_actor in this) {
            if (move_focus (direction)) {
                return true;
            }

            if (direction.is_forward ()) {
                return false;
            } else {
                return grab_focus ();
            }
        }

        // Focus is outside of us, try to take it
        if (direction.is_forward ()) {
            if (grab_focus ()) {
                return true;
            }

            return move_focus (direction);
        } else {
            if (move_focus (direction)) {
                return true;
            }

            return grab_focus ();
        }
    }

    private bool grab_focus () {
        if (!can_focus) {
            return false;
        }

        grab_key_focus ();

        return true;
    }

    protected virtual bool move_focus (FocusDirection direction) {
        var children = get_focusable_children ();

        FocusUtils.filter_children_for_direction (children, get_stage ().key_focus, direction);
        FocusUtils.sort_children_for_direction (children, direction);

        foreach (var child in children) {
            if (child.focus (direction)) {
                return true;
            }
        }

        return false;
    }

    private Gee.List<Focusable> get_focusable_children () {
        var focusable_children = new Gee.ArrayList<Focusable> ();
        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (child is Focusable && child.visible) {
                focusable_children.add ((Focusable) child);
            }
        }
        return focusable_children;
    }
}
