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
    public void filter_children_for_direction (Gee.List<Widget> children, Clutter.Actor focus_actor, FocusDirection direction) {
        Widget? focus_child = null;
        foreach (var child in children) {
            if (focus_actor in child) {
                focus_child = (Widget) child;
                break;
            }
        }

        var to_retain = new Gee.LinkedList<Widget> ();
        to_retain.add_all_iterator (children.filter ((c) => {
            if (focus_child == null || c == focus_child) {
                return true;
            }

            var focus_alloc = focus_child.allocation;
            var alloc = c.allocation;

            var horiz_overlap = alloc.x1 < focus_alloc.x2 && alloc.x2 > focus_alloc.x1;
            var vert_overlap = alloc.y1 < focus_alloc.y2 && alloc.y2 > focus_alloc.y1;

            if ((direction == UP || direction == DOWN) && !horiz_overlap ||
                (direction == LEFT || direction == RIGHT) && !vert_overlap
            ) {
                return false;
            }

            return (
                direction == UP && alloc.y2 <= focus_alloc.y1 ||
                direction == DOWN && alloc.y1 >= focus_alloc.y2 ||
                direction == LEFT && alloc.x2 <= focus_alloc.x1 ||
                direction == RIGHT && alloc.x1 >= focus_alloc.x2
            );
        }));

        children.retain_all (to_retain);
    }

    public void sort_children_for_direction (Gee.List<Widget> children, FocusDirection direction) {
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
