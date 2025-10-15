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

    public Mtk.Rectangle area { get; set; }

    public WindowManager wm { get; construct; }
    public WindowListModel windows { get; construct; }
    public float monitor_scale { get; construct set; }
    public bool overview_mode { get; construct; }

    private bool opened = false;

    private HashTable<Clutter.Actor, Clutter.ActorBox?> target_allocations = new HashTable<Clutter.Actor, Clutter.ActorBox?> (null, null);
    private HashTable<Clutter.Actor, Clutter.ActorBox?> origin_allocations = new HashTable<Clutter.Actor, Clutter.ActorBox?> (null, null);

    /**
     * The window that is currently selected via keyboard shortcuts.
     * It is not necessarily the same as the active window.
     */
    private unowned WindowClone? current_window = null;

    public WindowCloneContainer (WindowManager wm, WindowListModel windows, float monitor_scale, bool overview_mode = false) {
        Object (wm: wm, windows: windows, monitor_scale: monitor_scale, overview_mode: overview_mode);
    }

    construct {
        on_items_changed (0, 0, windows.get_n_items ());
        windows.items_changed.connect (on_items_changed);

        set_relayout_action (MULTITASKING_VIEW, true);
        set_relayout_action (SWITCH_WORKSPACE, true);
    }

    private void on_items_changed (uint position, uint removed, uint added) {
        // Used to make sure we only construct new window clones for windows that are really new
        // and not when only the position changed (e.g. when sorted)
        var to_remove = new HashTable<Meta.Window, WindowClone> (null, null);

        for (uint i = 0; i < removed; i++) {
            var window_clone = (WindowClone) get_child_at_index ((int) position);
            to_remove[window_clone.window] = window_clone;
            remove_child (window_clone);
        }

        for (int i = (int) position; i < position + added; i++) {
            var window = (Meta.Window) windows.get_item (i);

            WindowClone? clone = to_remove.take (window);

            if (clone == null) {
                clone = new WindowClone (wm, window, monitor_scale, overview_mode);
                clone.selected.connect ((_clone) => window_selected (_clone.window));
                clone.request_reposition.connect (() => reflow (false));
                bind_property ("monitor-scale", clone, "monitor-scale");
            }

            insert_child_at_index (clone, i);
        }

        // Make sure we release the reference on the window
        if (current_window != null && current_window.window in to_remove) {
            select_next_window (RIGHT, false);

            // There is no next window so select nothing
            if (current_window.window in to_remove) {
                current_window = null;
            }
        }

        // Don't reflow if only the sorting changed
        if (to_remove.size () > 0 || added != removed) {
            reflow (false);
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

            windows.sort ();
            reflow (true);
        } else if (action == MULTITASKING_VIEW) { // If we are open we only want to restack when we close
            windows.sort ();
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

        target_allocations.remove_all ();
        origin_allocations.remove_all ();
        foreach (var tilable in calculate_grid_placement (area, windows)) {
            var geom = wm.get_display ().get_monitor_geometry (tilable.clone.window.get_monitor ());
            var rect = tilable.clone.window.get_frame_rect ();

            origin_allocations[tilable.clone] = InternalUtils.actor_box_from_rect (rect.x - geom.x, rect.y - geom.y, rect.width, rect.height);
            target_allocations[tilable.clone] = InternalUtils.actor_box_from_rect (tilable.rect.x, tilable.rect.y, tilable.rect.width, tilable.rect.height);
        }
    }

    protected override void allocate (Clutter.ActorBox box) {
        set_allocation (box);

        var static_windows = StaticWindowContainer.get_instance (wm.get_display ());
        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (child is WindowClone && static_windows.is_static (child.window)) {
                float x, y;
                get_transformed_position (out x, out y);

                var allocation = origin_allocations[child];
                allocation.set_origin (allocation.x1 - x, allocation.y1 - y);
                child.allocate (allocation);
                continue;
            }

            var target_allocation = target_allocations[child];
            var origin_allocation = origin_allocations[child];

            if (target_allocation == null || origin_allocation == null) {
                child.allocate ({0, 0, 0, 0});
                continue;
            }

            if (!animating) {
                child.save_easing_state ();
                child.set_easing_duration (Utils.get_animation_duration (MultitaskingView.ANIMATION_DURATION));
                child.set_easing_mode (EASE_OUT_QUAD);
            }

            child.allocate (
                origin_allocation.interpolate (target_allocation, get_current_progress (MULTITASKING_VIEW))
            );

            if (!animating) {
                child.restore_easing_state ();
            }
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

    // Code ported from KWin present windows effect
    // https://projects.kde.org/projects/kde/kde-workspace/repository/revisions/master/entry/kwin/effects/presentwindows/presentwindows.cpp

    // some math utilities
    private static float squared_distance (Graphene.Point a, Graphene.Point b) {
        var k1 = b.x - a.x;
        var k2 = b.y - a.y;

        return k1 * k1 + k2 * k2;
    }

    private static Mtk.Rectangle rect_adjusted (Mtk.Rectangle rect, int dx1, int dy1, int dx2, int dy2) {
        return {rect.x + dx1, rect.y + dy1, rect.width + (-dx1 + dx2), rect.height + (-dy1 + dy2)};
    }

    private static Graphene.Point rect_center (Mtk.Rectangle rect) {
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
        Graphene.Point[] slot_centers = {};
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
            var slot_candidate_distance = float.MAX;
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
                    (int) (rect_center (target).x - Math.floorf (rect.width * scale) / 2),
                    (int) (rect_center (target).y - Math.floorf (rect.height * scale) / 2),
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
