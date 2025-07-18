/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2014 Tom Beckmann
 *                         2025 elementary, Inc. (https://elementary.io)
 */

/**
 * Container which controls the layout of a set of WindowClones.
 */
public class Gala.WindowCloneContainer : ActorTarget {
    public signal void window_selected (Meta.Window window);
    public signal void requested_close ();
    public signal void last_window_closed ();

    public int padding_top { get; set; default = 12; }
    public int padding_left { get; set; default = 12; }
    public int padding_right { get; set; default = 12; }
    public int padding_bottom { get; set; default = 12; }

    public WindowManager wm { get; construct; }
    public float monitor_scale { get; construct set; }
    public bool overview_mode { get; construct; }

    private bool opened = false;

    /**
     * The window that is currently selected via keyboard shortcuts.
     * It is not necessarily the same as the active window.
     */
    private unowned WindowClone? current_window = null;

    public WindowCloneContainer (WindowManager wm, float monitor_scale, bool overview_mode = false) {
        Object (wm: wm, monitor_scale: monitor_scale, overview_mode: overview_mode);
    }

    /**
     * Create a WindowClone for a Meta.Window and add it to the group
     *
     * @param window The window for which to create the WindowClone for
     */
    public void add_window (Meta.Window window) {
        var windows = new List<Meta.Window> ();
        windows.append (window);
        foreach (unowned var clone in (GLib.List<weak WindowClone>) get_children ()) {
            windows.append (clone.window);
        }

        var new_window = new WindowClone (wm, window, monitor_scale, overview_mode);
        new_window.selected.connect ((_new_window) => window_selected (_new_window.window));
        new_window.request_reposition.connect (() => reflow (false));
        new_window.destroy.connect ((_new_window) => {
            // make sure to release reference if the window is selected
            if (_new_window == current_window) {
                select_next_window (Meta.MotionDirection.RIGHT, false);
            }

            // if window is still selected, reset the selection
            if (_new_window == current_window) {
                current_window = null;
            }

            reflow (false);
        });
        bind_property ("monitor-scale", new_window, "monitor-scale");

        unowned Meta.Window? target = null;
        foreach (unowned var w in sort_windows (windows)) {
            if (w != window) {
                target = w;
                continue;
            }
            break;
        }

        // top most or no other children
        if (target == null) {
            add_child (new_window);
        }

        foreach (unowned var clone in (GLib.List<weak WindowClone>) get_children ()) {
            if (target == clone.window) {
                insert_child_below (new_window, clone);
                break;
            }
        }

        reflow (false);
    }

    /**
     * Find and remove the WindowClone for a MetaWindow
     */
    public void remove_window (Meta.Window window) {
        foreach (unowned var clone in (GLib.List<weak WindowClone>) get_children ()) {
            if (clone.window == window) {
                remove_child (clone);
                reflow (false);
                break;
            }
        }

        if (get_n_children () == 0) {
            last_window_closed ();
        }
    }

    public override void start_progress (GestureAction action) {
        if (!opened) {
            opened = true;

            if (current_window != null) {
                current_window.active = false;
            }

            unowned var focus_window = wm.get_display ().focus_window;
            foreach (unowned var clone in (GLib.List<weak WindowClone>) get_children ()) {
                if (clone.window == focus_window) {
                    current_window = clone;
                    break;
                }
            }

            restack_windows ();
            reflow (true);
        } else if (action == MULTITASKING_VIEW) { // If we are open we only want to restack when we close
            restack_windows ();
        }
    }

    public override void commit_progress (GestureAction action, double to) {
        switch (action) {
            case MULTITASKING_VIEW:
                opened = to > 0.5;
                break;

            case SWITCH_WORKSPACE:
                opened = get_current_commit (MULTITASKING_VIEW) > 0.5;
                break;

            default:
                break;
        }
    }

    /**
     * Sort the windows z-order by their actual stacking to make intersections
     * during animations correct.
     */
    private void restack_windows () {
        var children = (GLib.List<weak WindowClone>) get_children ();

        var windows = new GLib.List<Meta.Window> ();
        foreach (unowned var clone in children) {
            windows.prepend (clone.window);
        }

        var windows_ordered = sort_windows (windows);
        windows_ordered.reverse ();

        var i = 0;
        foreach (unowned var window in windows_ordered) {
            foreach (unowned var clone in children) {
                if (clone.window == window) {
                    set_child_at_index (clone, i);
                    children.remove (clone);
                    i++;
                    break;
                }
            }
        }
    }

    /**
     * Recalculate the tiling positions of the windows and animate them to the resulting spots.
     */
    private void reflow (bool view_toggle) {
        if (!opened || get_n_children () == 0) {
            return;
        }

        var windows = new GLib.List<TilableWindow?> ();
        foreach (unowned var clone in (GLib.List<weak WindowClone>) get_children ()) {
            windows.prepend ({ clone, clone.window.get_frame_rect () });
        }

        // make sure the windows are always in the same order so the algorithm
        // doesn't give us different slots based on stacking order, which can lead
        // to windows flying around weirdly
        windows.sort ((a, b) => {
            var seq_a = ((WindowClone) a.clone).window.get_stable_sequence ();
            var seq_b = ((WindowClone) b.clone).window.get_stable_sequence ();
            return (int) (seq_b - seq_a);
        });

        Mtk.Rectangle area = {
            padding_left,
            padding_top,
            (int) width - padding_left - padding_right,
            (int) height - padding_top - padding_bottom
        };

        foreach (var tilable in calculate_grid_placement (area, windows)) {
            tilable.clone.take_slot (tilable.rect, !view_toggle);
        }
    }

    /**
     * Collect key events, mainly for redirecting them to the WindowCloneContainers to
     * select the active window.
     */
    public override bool key_press_event (Clutter.Event event) {
        if (!opened) {
            return Clutter.EVENT_PROPAGATE;
        }

        switch (event.get_key_symbol ()) {
            case Clutter.Key.Escape:
                requested_close ();
                break;
            case Clutter.Key.Down:
                select_next_window (Meta.MotionDirection.DOWN, true);
                break;
            case Clutter.Key.Up:
                select_next_window (Meta.MotionDirection.UP, true);
                break;
            case Clutter.Key.Left:
                select_next_window (Meta.MotionDirection.LEFT, true);
                break;
            case Clutter.Key.Right:
                select_next_window (Meta.MotionDirection.RIGHT, true);
                break;
            case Clutter.Key.Return:
            case Clutter.Key.KP_Enter:
                if (current_window == null) {
                    requested_close ();
                } else {
                    window_selected (current_window.window);
                }
                break;
        }

        return Clutter.EVENT_STOP;
    }

    /**
     * Look for the next window in a direction and make this window the new current_window.
     * Used for keyboard navigation.
     *
     * @param direction   The MetaMotionDirection in which to search for windows for.
     * @param user_action Whether we must select a window and, if failed, play a bell sound.
     */
    public void select_next_window (Meta.MotionDirection direction, bool user_action) {
        if (get_n_children () == 0) {
            return;
        }

        WindowClone? closest = null;

        if (current_window == null) {
            closest = (WindowClone) get_child_at_index (0);
        } else {
            var current_rect = current_window.slot;

            foreach (unowned var clone in (GLib.List<weak WindowClone>) get_children ()) {
                if (clone == current_window) {
                    continue;
                }

                var window_rect = clone.slot;

                if (window_rect == null) {
                    continue;
                }

                if (direction == LEFT) {
                    if (window_rect.x > current_rect.x) {
                        continue;
                    }

                    // test for vertical intersection
                    if (window_rect.y + window_rect.height > current_rect.y
                        && window_rect.y < current_rect.y + current_rect.height) {

                        if (closest == null || closest.slot.x < window_rect.x) {
                            closest = clone;
                        }
                    }
                } else if (direction == RIGHT) {
                    if (window_rect.x < current_rect.x) {
                        continue;
                    }

                    // test for vertical intersection
                    if (window_rect.y + window_rect.height > current_rect.y
                        && window_rect.y < current_rect.y + current_rect.height) {

                        if (closest == null || closest.slot.x > window_rect.x) {
                            closest = clone;
                        }
                    }
                } else if (direction == UP) {
                    if (window_rect.y > current_rect.y) {
                        continue;
                    }

                    // test for horizontal intersection
                    if (window_rect.x + window_rect.width > current_rect.x
                        && window_rect.x < current_rect.x + current_rect.width) {

                        if (closest == null || closest.slot.y < window_rect.y) {
                            closest = clone;
                        }
                    }
                } else if (direction == DOWN) {
                    if (window_rect.y < current_rect.y) {
                        continue;
                    }

                    // test for horizontal intersection
                    if (window_rect.x + window_rect.width > current_rect.x
                        && window_rect.x < current_rect.x + current_rect.width) {

                        if (closest == null || closest.slot.y > window_rect.y) {
                            closest = clone;
                        }
                    }
                } else {
                    warning ("Invalid direction");
                    break;
                }
            }
        }

        if (closest == null) {
            if (current_window != null && user_action) {
                InternalUtils.bell_notify (wm.get_display ());
                current_window.active = true;
            }
            return;
        }

        if (current_window != null) {
            current_window.active = false;
        }

        if (user_action) {
            closest.active = true;
        }

        current_window = closest;
    }

    /**
     * Sorts the windows by stacking order so that the window on active workspaces come first.
     */
    private GLib.SList<weak Meta.Window> sort_windows (GLib.List<Meta.Window> windows) {
        unowned var display = wm.get_display ();

        var windows_on_active_workspace = new GLib.SList<Meta.Window> ();
        var windows_on_other_workspaces = new GLib.SList<Meta.Window> ();
        unowned var active_workspace = display.get_workspace_manager ().get_active_workspace ();
        foreach (unowned var window in windows) {
            if (window.get_workspace () == active_workspace) {
                windows_on_active_workspace.append (window);
            } else {
                windows_on_other_workspaces.append (window);
            }
        }

        var sorted_windows = new GLib.SList<weak Meta.Window> ();
        var windows_on_active_workspace_sorted = display.sort_windows_by_stacking (windows_on_active_workspace);
        windows_on_active_workspace_sorted.reverse ();
        var windows_on_other_workspaces_sorted = display.sort_windows_by_stacking (windows_on_other_workspaces);
        windows_on_other_workspaces_sorted.reverse ();
        sorted_windows.concat ((owned) windows_on_active_workspace_sorted);
        sorted_windows.concat ((owned) windows_on_other_workspaces_sorted);

        return sorted_windows;
    }


    // Code ported from KWin present windows effect
    // https://projects.kde.org/projects/kde/kde-workspace/repository/revisions/master/entry/kwin/effects/presentwindows/presentwindows.cpp

    // some math utilities
    private static int squared_distance (Gdk.Point a, Gdk.Point b) {
        var k1 = b.x - a.x;
        var k2 = b.y - a.y;

        return k1 * k1 + k2 * k2;
    }

    private static Mtk.Rectangle rect_adjusted (Mtk.Rectangle rect, int dx1, int dy1, int dx2, int dy2) {
        return {rect.x + dx1, rect.y + dy1, rect.width + (-dx1 + dx2), rect.height + (-dy1 + dy2)};
    }

    private static Gdk.Point rect_center (Mtk.Rectangle rect) {
        return {rect.x + rect.width / 2, rect.y + rect.height / 2};
    }

    private struct TilableWindow {
        unowned WindowClone clone;
        Mtk.Rectangle rect;
    }

    /**
     * Careful: List<TilableWindow?> windows will be modified in place and shouldn't be used afterwards.
     */
    private static GLib.List<TilableWindow?> calculate_grid_placement (Mtk.Rectangle area, GLib.List<TilableWindow?> windows) {
        uint window_count = windows.length ();
        int columns = (int) Math.ceil (Math.sqrt (window_count));
        int rows = (int) Math.ceil (window_count / (double) columns);

        // Assign slots
        int slot_width = area.width / columns;
        int slot_height = area.height / rows;

        TilableWindow?[] taken_slots = {};
        taken_slots.resize (rows * columns);

        // precalculate all slot centers
        Gdk.Point[] slot_centers = {};
        slot_centers.resize (rows * columns);
        for (int x = 0; x < columns; x++) {
            for (int y = 0; y < rows; y++) {
                slot_centers[x + y * columns] = {
                    area.x + slot_width * x + slot_width / 2,
                    area.y + slot_height * y + slot_height / 2
                };
            }
        }

        // Assign each window to the closest available slot
        while (windows.length () > 0) {
            unowned var link = windows.nth (0);
            var window = link.data;
            var rect = window.rect;

            var slot_candidate = -1;
            var slot_candidate_distance = int.MAX;
            var pos = rect_center (rect);

            // all slots
            for (int i = 0; i < columns * rows; i++) {
                if (i > window_count - 1)
                    break;

                var dist = squared_distance (pos, slot_centers[i]);

                if (dist < slot_candidate_distance) {
                    // window is interested in this slot
                    var occupier = taken_slots[i];
                    if (occupier == window)
                        continue;

                    if (occupier == null || dist < squared_distance (rect_center (occupier.rect), slot_centers[i])) {
                        // either nobody lives here, or we're better - takeover the slot if it's our best
                        slot_candidate = i;
                        slot_candidate_distance = dist;
                    }
                }
            }

            if (slot_candidate == -1)
                continue;

            if (taken_slots[slot_candidate] != null)
                windows.prepend (taken_slots[slot_candidate]);

            windows.remove_link (link);
            taken_slots[slot_candidate] = window;
        }

        var result = new GLib.List<TilableWindow?> ();

        // see how many windows we have on the last row
        int left_over = (int) window_count - columns * (rows - 1);

        for (int slot = 0; slot < columns * rows; slot++) {
            var window = taken_slots[slot];
            // some slots might be empty
            if (window == null)
                continue;

            var rect = window.rect;

            // Work out where the slot is
            Mtk.Rectangle target = {
                area.x + (slot % columns) * slot_width,
                area.y + (slot / columns) * slot_height,
                slot_width,
                slot_height
            };
            target = rect_adjusted (target, 10, 10, -10, -10);

            float scale;
            if (target.width / (double) rect.width < target.height / (double) rect.height) {
                // Center vertically
                scale = target.width / (float) rect.width;
                target.y += (target.height - (int) (rect.height * scale)) / 2;
                target.height = (int) Math.floorf (rect.height * scale);
            } else {
                // Center horizontally
                scale = target.height / (float) rect.height;
                target.x += (target.width - (int) (rect.width * scale)) / 2;
                target.width = (int) Math.floorf (rect.width * scale);
            }

            // Don't scale the windows too much
            if (scale > 1.0) {
                scale = 1.0f;
                target = {
                    rect_center (target).x - (int) Math.floorf (rect.width * scale) / 2,
                    rect_center (target).y - (int) Math.floorf (rect.height * scale) / 2,
                    (int) Math.floorf (scale * rect.width),
                    (int) Math.floorf (scale * rect.height)
                };
            }

            // put the last row in the center, if necessary
            if (left_over != columns && slot >= columns * (rows - 1))
                target.x += (columns - left_over) * slot_width / 2;

            result.prepend ({ window.clone, target });
        }

        result.reverse ();
        return result;
    }
}
