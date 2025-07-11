/*
 * Copyright 2012 Tom Beckmann
 * Copyright 2012 Rico Tzschichholz
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public enum InputArea {
        NONE,
        FULLSCREEN,
        DEFAULT
    }

    public class InternalUtils {
        /**
         * set the area where clutter can receive events
         **/
        public static void set_input_area (Meta.Display display, InputArea area) {
            if (Meta.Util.is_wayland_compositor ()) {
                return;
            }

            X.Xrectangle[] rects = {};

            switch (area) {
                case InputArea.FULLSCREEN:
                    int width, height;
                    display.get_size (out width, out height);

                    X.Xrectangle rect = {0, 0, (ushort)width, (ushort)height};
                    rects = {rect};
                    break;

                case InputArea.DEFAULT:
                    // add plugin's requested areas
                    foreach (var rect in PluginManager.get_default ().get_regions ()) {
                        rects += rect;
                    }

                    break;

                case InputArea.NONE:
                default:
                    rects = {};
                    break;
            }

            unowned Meta.X11Display x11display = display.get_x11_display ();
#if HAS_MUTTER47
            x11display.set_stage_input_region (rects);
#else
            var xregion = X.Fixes.create_region (x11display.get_xdisplay (), rects);
            x11display.set_stage_input_region (xregion);
#endif
        }

        /**
         * Inserts a workspace at the given index. To ensure the workspace is not immediately
         * removed again when in dynamic workspaces, the window is first placed on it.
         *
         * @param index  The index at which to insert the workspace
         * @param new_window A window that should be moved to the new workspace
         */
        public static void insert_workspace_with_window (int index, Meta.Window new_window) {
            unowned WorkspaceManager workspace_manager = WorkspaceManager.get_default ();
            workspace_manager.freeze_remove ();

            new_window.change_workspace_by_index (index, false);

#if HAS_MUTTER48
            unowned List<Meta.WindowActor> actors = new_window.get_display ().get_compositor ().get_window_actors ();
#else
            unowned List<Meta.WindowActor> actors = new_window.get_display ().get_window_actors ();
#endif
            foreach (unowned Meta.WindowActor actor in actors) {
                if (actor.is_destroyed ())
                    continue;

                unowned Meta.Window window = actor.get_meta_window ();
                if (window == new_window)
                    continue;

                var current_index = window.get_workspace ().index ();
                if (current_index >= index
                    && !window.on_all_workspaces) {
                    window.change_workspace_by_index (current_index + 1, true);
                }
            }

            workspace_manager.thaw_remove ();
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

        public struct TilableWindow {
            Mtk.Rectangle rect;
            unowned WindowClone id;
        }

        /**
         * Careful: List<TilableWindow?> windows will be modified in place and shouldn't be used afterwards.
         */
        public static List<TilableWindow?> calculate_grid_placement (Mtk.Rectangle area, List<TilableWindow?> windows) {
            uint window_count = windows.length ();
            int columns = (int)Math.ceil (Math.sqrt (window_count));
            int rows = (int)Math.ceil (window_count / (double)columns);

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
                unowned List<TilableWindow?> link = windows.nth (0);
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

            var result = new List<TilableWindow?> ();

            // see how many windows we have on the last row
            int left_over = (int)window_count - columns * (rows - 1);

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
                if (target.width / (double)rect.width < target.height / (double)rect.height) {
                    // Center vertically
                    scale = target.width / (float)rect.width;
                    target.y += (target.height - (int)(rect.height * scale)) / 2;
                    target.height = (int)Math.floorf (rect.height * scale);
                } else {
                    // Center horizontally
                    scale = target.height / (float)rect.height;
                    target.x += (target.width - (int)(rect.width * scale)) / 2;
                    target.width = (int)Math.floorf (rect.width * scale);
                }

                // Don't scale the windows too much
                if (scale > 1.0) {
                    scale = 1.0f;
                    target = {rect_center (target).x - (int)Math.floorf (rect.width * scale) / 2,
                              rect_center (target).y - (int)Math.floorf (rect.height * scale) / 2,
                              (int)Math.floorf (scale * rect.width),
                              (int)Math.floorf (scale * rect.height)};
                }

                // put the last row in the center, if necessary
                if (left_over != columns && slot >= columns * (rows - 1))
                    target.x += (columns - left_over) * slot_width / 2;

                result.prepend ({ target, window.id });
            }

            result.reverse ();
            return result;
        }

        /*
         * Sorts the windows by stacking order so that the window on active workspaces come first.
        */
        public static SList<weak Meta.Window> sort_windows (Meta.Display display, List<Meta.Window> windows) {
            var windows_on_active_workspace = new SList<Meta.Window> ();
            var windows_on_other_workspaces = new SList<Meta.Window> ();
            unowned var active_workspace = display.get_workspace_manager ().get_active_workspace ();
            foreach (unowned var window in windows) {
                if (window.get_workspace () == active_workspace) {
                    windows_on_active_workspace.append (window);
                } else {
                    windows_on_other_workspaces.append (window);
                }
            }

            var sorted_windows = new SList<weak Meta.Window> ();
            var windows_on_active_workspace_sorted = display.sort_windows_by_stacking (windows_on_active_workspace);
            windows_on_active_workspace_sorted.reverse ();
            var windows_on_other_workspaces_sorted = display.sort_windows_by_stacking (windows_on_other_workspaces);
            windows_on_other_workspaces_sorted.reverse ();
            sorted_windows.concat ((owned) windows_on_active_workspace_sorted);
            sorted_windows.concat ((owned) windows_on_other_workspaces_sorted);

            return sorted_windows;
        }

        public static inline bool get_window_is_normal (Meta.Window window) {
            switch (window.window_type) {
                case Meta.WindowType.NORMAL:
                case Meta.WindowType.DIALOG:
                case Meta.WindowType.MODAL_DIALOG:
                    return true;
                default:
                    return false;
            }
        }

        /**
         * Returns the workspaces geometry following the only_on_primary settings.
         */
        public static Mtk.Rectangle get_workspaces_geometry (Meta.Display display) {
            if (Meta.Prefs.get_workspaces_only_on_primary ()) {
                return display.get_monitor_geometry (display.get_primary_monitor ());
            } else {
                float screen_width, screen_height;
                display.get_size (out screen_width, out screen_height);
                return { 0, 0, (int) screen_width, (int) screen_height };
            }
        }

        public static Clutter.ActorBox actor_box_from_rect (float x, float y, float width, float height) {
            var actor_box = Clutter.ActorBox ();
            actor_box.init_rect (x, y, width, height);
            Clutter.ActorBox.clamp_to_pixel (ref actor_box);

            return actor_box;
        }

        public delegate void WindowActorReadyCallback (Meta.WindowActor window_actor);

        public static void wait_for_window_actor (Meta.Window window, owned WindowActorReadyCallback callback) {
            unowned var window_actor = (Meta.WindowActor) window.get_compositor_private ();
            if (window_actor != null) {
                callback (window_actor);
                return;
            }

            Idle.add (() => {
                window_actor = (Meta.WindowActor) window.get_compositor_private ();

                if (window_actor != null) {
                    callback (window_actor);
                }

                return Source.REMOVE;
            });
        }

        public static void wait_for_window_actor_visible (Meta.Window window, owned WindowActorReadyCallback callback) {
            wait_for_window_actor (window, (window_actor) => {
                if (window_actor.visible) {
                    callback (window_actor);
                } else {
                    ulong show_handler = 0;
                    show_handler = window_actor.show.connect (() => {
                        window_actor.disconnect (show_handler);
                        callback (window_actor);
                    });
                }
            });
        }

        public static void clutter_actor_reparent (Clutter.Actor actor, Clutter.Actor new_parent) {
            if (actor == new_parent) {
                return;
            }

            actor.ref ();
            actor.get_parent ().remove_child (actor);
            new_parent.add_child (actor);
            actor.unref ();
        }

        public static void bell_notify (Meta.Display display) {
#if HAS_MUTTER48
            display.get_compositor ().get_stage ().context.get_backend ().get_default_seat ().bell_notify ();
#elif HAS_MUTTER47
            display.get_stage ().context.get_backend ().get_default_seat ().bell_notify ();
#else
            Clutter.get_default_backend ().get_default_seat ().bell_notify ();
#endif
        }

        public static bool get_x11_in_fullscreen (Meta.Display display) {
            var primary_monitor = display.get_primary_monitor ();
            var is_in_fullscreen = display.get_monitor_in_fullscreen (primary_monitor);
            return !Meta.Util.is_wayland_compositor () && is_in_fullscreen;
        }
    }
}
