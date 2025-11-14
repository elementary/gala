/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public enum Gala.FocusDirection {
    UP,
    DOWN,
    LEFT,
    RIGHT;

    public bool is_forward () {
        return this == DOWN || this == RIGHT;
    }

    public static FocusDirection? get_for_event (Clutter.Event event) {
        switch (event.get_key_symbol ()) {
            case Clutter.Key.Up: return UP;
            case Clutter.Key.Down: return DOWN;
            case Clutter.Key.Left: return LEFT;
            case Clutter.Key.Right: return RIGHT;
        }

        return null;
    }
}

namespace Gala.FocusUtils {
    public void filter_children_for_direction (Gee.List<Focusable> children, Clutter.Actor focus_actor, FocusDirection direction) {
        Focusable? focus_child = null;
        foreach (var child in children) {
            if (focus_actor in child) {
                focus_child = (Focusable) child;
                break;
            }
        }

        var to_retain = new Gee.LinkedList<Focusable> ();
        to_retain.add_all_iterator (children.filter ((c) => {
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

        children.retain_all (to_retain);
    }

    private inline Mtk.Rectangle get_allocation_rect (Clutter.Actor actor) {
        return {(int) actor.x, (int) actor.y, (int) actor.width, (int) actor.height};
    }

    public void sort_children_for_direction (Gee.List<Focusable> children, FocusDirection direction) {
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
}
