/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Gala.Focusable : Clutter.Actor {
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

        var possible_children = new Gee.ArrayList<Focusable> ();
        possible_children.add_all_iterator (get_focusable_children ().filter ((c) => {
            if (focus_child == null || c == focus_child) {
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

        possible_children.sort ((a, b) => {
            if (direction == UP && a.y + a.height > b.y + b.height ||
                direction == DOWN && a.y < b.y ||
                direction == LEFT && a.x + a.width > b.x + b.width ||
                direction == RIGHT && a.x < b.x
            ) {
                return -1;
            }

            return 1;
        });

        foreach (var child in possible_children) {
            if (child.focus (direction)) {
                return true;
            }
        }

        return false;
    }

    private Mtk.Rectangle get_allocation_rect (Clutter.Actor actor) {
        return {(int) actor.x, (int) actor.y, (int) actor.width, (int) actor.height};
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

    private bool grab_focus () {
        if (!can_focus ()) {
            return false;
        }

        get_stage ().set_key_focus (this);

        return true;
    }

    public virtual bool can_focus () {
        return false;
    }

    public void mark_root (Clutter.Stage stage) {
        stage.key_press_event.connect (on_key_press_event);
    }

    private bool on_key_press_event (Clutter.Event event) {
        if (!mapped) {
            return Clutter.EVENT_PROPAGATE;
        }

        switch (event.get_key_symbol ()) {
            case Clutter.Key.Tab:
                if (SHIFT_MASK in event.get_state ()) {
                    focus (PREVIOUS);
                } else {
                    focus (NEXT);
                }
                return Clutter.EVENT_STOP;
            case Clutter.Key.Up:
                focus (UP);
                return Clutter.EVENT_STOP;
            case Clutter.Key.Left:
                focus (LEFT);
                return Clutter.EVENT_STOP;
            case Clutter.Key.Down:
                focus (DOWN);
                return Clutter.EVENT_STOP;
            case Clutter.Key.Right:
                focus (RIGHT);
                return Clutter.EVENT_STOP;
            default:
                return Clutter.EVENT_PROPAGATE;
        }
    }
}
