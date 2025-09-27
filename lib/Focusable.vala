/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Gala.Focusable : Clutter.Actor{
    public enum FocusDirection {
        UP,
        DOWN,
        LEFT,
        RIGHT,
        NEXT,
        PREVIOUS;

        public bool is_forward () {
            return this == DOWN || this == RIGHT || this == NEXT;
        }

        public static FocusDirection? get_for_event (Clutter.Event event) {
            switch (event.get_key_symbol ()) {
                case Clutter.Key.Up: return UP;
                case Clutter.Key.Down: return DOWN;
                case Clutter.Key.Left: return LEFT;
                case Clutter.Key.Right: return RIGHT;
                case Clutter.Key.Tab:
                    if (SHIFT_MASK in event.get_state ()) {
                        return PREVIOUS;
                    } else {
                        return NEXT;
                    }
            }

            return null;
        }
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

    protected virtual bool move_focus (FocusDirection direction) {
        var children = get_focusable_children ();

        filter_children_for_direction (children, direction);

        switch (direction) {
            case NEXT:
                sort_children_for_direction (children, DOWN);
                sort_children_for_direction (children, RIGHT);
                break;

            case PREVIOUS:
                sort_children_for_direction (children, UP);
                sort_children_for_direction (children, LEFT);
                break;

            default:
                sort_children_for_direction (children, direction);
                break;
        }

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
            if (child is Focusable) {
                focusable_children.add ((Focusable) child);
            }
        }
        return focusable_children;
    }

    private void filter_children_for_direction (Gee.List<Focusable> children, FocusDirection direction) {
        var focus_actor = get_stage ().get_key_focus ();

        Focusable? focus_child = null;
        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (focus_actor in child) {
                if (child is Focusable) {
                    focus_child = (Focusable) child;
                }
                break;
            }
        }

        var to_retain = new Gee.LinkedList<Focusable> ();
        to_retain.add_all_iterator (children.filter ((c) => {
            if (focus_child == null || c == focus_child || direction == NEXT || direction == PREVIOUS) {
                return true;
            }

            var focus_rect = get_allocation_rect (focus_child);
            var rect = get_allocation_rect (c);

            if ((direction == UP || direction == DOWN) && !rect.horiz_overlap (focus_rect) ||
                (direction == LEFT || direction == RIGHT) && !rect.vert_overlap (focus_rect)
            ) {
                return false;
            }

            return (
                direction == UP && rect.y + rect.height <= focus_rect.y ||
                direction == DOWN && rect.y >= focus_rect.y + focus_rect.height ||
                direction == LEFT && rect.x + rect.width <= focus_rect.x ||
                direction == RIGHT && rect.x >= focus_rect.x + focus_rect.width
            );
        }));

        children.retain_all (to_retain);
    }

    private inline Mtk.Rectangle get_allocation_rect (Clutter.Actor actor) {
        return {(int) actor.x, (int) actor.y, (int) actor.width, (int) actor.height};
    }

    private void sort_children_for_direction (Gee.List<Focusable> children, FocusDirection direction) {
        children.sort ((a, b) => {
            if (direction == UP && a.y + a.height > b.y + b.height ||
                direction == DOWN && a.y < b.y ||
                direction == LEFT && a.x + a.width > b.x + b.width ||
                direction == RIGHT && a.x < b.x
            ) {
                return -1;
            }

            return 1;
        });
    }

    private bool grab_focus () {
        if (!can_focus ()) {
            return false;
        }

        get_stage ().set_key_focus (this);
        notify_visible_focus_changed ();
        key_focus_out.connect (notify_visible_focus_changed);

        return true;
    }

    public virtual bool can_focus () {
        return false;
    }

    internal void notify_visible_focus_changed () {
        var stage = get_stage ();
        update_focus (stage?.get_key_focus () == this && FocusController.get_default (stage).focus_visible);
    }

    protected virtual void update_focus (bool has_visible_focus) { }
}
