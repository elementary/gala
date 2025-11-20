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

    public int padding_top { get; set; default = 12; }
    public int padding_left { get; set; default = 12; }
    public int padding_right { get; set; default = 12; }
    public int padding_bottom { get; set; default = 12; }

    public WindowManager wm { get; construct; }
    public WindowListModel windows { get; construct; }
    public float monitor_scale { get; construct set; }
    public WindowClone.Mode window_clone_mode { get; construct; }

    private bool opened = false;

    public WindowCloneContainer (
        WindowManager wm, WindowListModel windows, float monitor_scale,
        WindowClone.Mode window_clone_mode = MULTITASKING_VIEW
    ) {
        Object (wm: wm, windows: windows, monitor_scale: monitor_scale, window_clone_mode: window_clone_mode);
    }

    construct {
        on_items_changed (0, 0, windows.get_n_items ());
        windows.items_changed.connect (on_items_changed);
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
                clone = new WindowClone (wm, window, monitor_scale, window_clone_mode);
                clone.selected.connect ((_clone) => window_selected (_clone.window));
                clone.request_reposition.connect (() => reflow (false));
                bind_property ("monitor-scale", clone, "monitor-scale");
            }

            insert_child_at_index (clone, i);
        }

        // Don't reflow if only the sorting changed
        if (to_remove.size () > 0 || added != removed) {
            reflow (false);
        }
    }

    public override void start_progress (GestureAction action) {
        if (!opened) {
            opened = true;

            unowned var focus_window = wm.get_display ().focus_window;
            foreach (unowned var clone in (GLib.List<weak WindowClone>) get_children ()) {
                if (clone.window == focus_window) {
                    clone.grab_key_focus ();
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

    // Code ported from KWin present windows effect
    // https://projects.kde.org/projects/kde/kde-workspace/repository/revisions/master/entry/kwin/effects/presentwindows/presentwindows.cpp

    // some math utilities
    private static float squared_distance (Graphene.Point a, Graphene.Point b) {
        var k1 = b.x - a.x;
        var k2 = b.y - a.y;

        return k1 * k1 + k2 * k2;
    }

    private static Mtk.Rectangle rect_adjusted (Mtk.Rectangle rect, int dw, int dh) {
        return { rect.x + dw / 2, rect.y + dh / 2, rect.width - dw, rect.height - dh };
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
    private GLib.List<TilableWindow?> calculate_grid_placement (Mtk.Rectangle area, GLib.List<TilableWindow?> windows) {
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

        var button_size = Utils.calculate_button_size (monitor_scale);

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
            target = rect_adjusted (target, button_size, button_size);

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
