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
        public static bool workspaces_only_on_primary () {
            return Meta.Prefs.get_dynamic_workspaces ()
                && Meta.Prefs.get_workspaces_only_on_primary ();
        }

        /**
         * set the area where clutter can receive events
         **/
        public static void set_input_area (Meta.Display display, InputArea area) {
            if (Meta.Util.is_wayland_compositor ()) {
                return;
            }

            X.Xrectangle[] rects = {};
            int width, height;
            display.get_size (out width, out height);
            var geometry = display.get_monitor_geometry (display.get_primary_monitor ());

            switch (area) {
                case InputArea.FULLSCREEN:
                    X.Xrectangle rect = {0, 0, (ushort)width, (ushort)height};
                    rects = {rect};
                    break;
                case InputArea.DEFAULT:
                    var settings = new GLib.Settings (Config.SCHEMA + ".behavior");

                    // if ActionType is NONE make it 0 sized
                    ushort tl_size = (settings.get_enum ("hotcorner-topleft") != ActionType.NONE ? 1 : 0);
                    ushort tr_size = (settings.get_enum ("hotcorner-topright") != ActionType.NONE ? 1 : 0);
                    ushort bl_size = (settings.get_enum ("hotcorner-bottomleft") != ActionType.NONE ? 1 : 0);
                    ushort br_size = (settings.get_enum ("hotcorner-bottomright") != ActionType.NONE ? 1 : 0);

                    X.Xrectangle topleft = {(short)geometry.x, (short)geometry.y, tl_size, tl_size};
                    X.Xrectangle topright = {(short)(geometry.x + geometry.width - 1), (short)geometry.y, tr_size, tr_size};
                    X.Xrectangle bottomleft = {(short)geometry.x, (short)(geometry.y + geometry.height - 1), bl_size, bl_size};
                    X.Xrectangle bottomright = {(short)(geometry.x + geometry.width - 1), (short)(geometry.y + geometry.height - 1), br_size, br_size};

                    rects = {topleft, topright, bottomleft, bottomright};

                    // add plugin's requested areas
                    foreach (var rect in PluginManager.get_default ().get_regions ()) {
                        rects += rect;
                    }

                    break;
                case InputArea.NONE:
                default:
#if !HAS_MUTTER44
                    unowned Meta.X11Display x11display = display.get_x11_display ();
                    x11display.clear_stage_input_region ();
                    return;
#else
                    rects = {};
                    break;
#endif
            }

            unowned Meta.X11Display x11display = display.get_x11_display ();
            var xregion = X.Fixes.create_region (x11display.get_xdisplay (), rects);
            x11display.set_stage_input_region (xregion);
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

            unowned List<Meta.WindowActor> actors = new_window.get_display ().get_window_actors ();
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
            workspace_manager.cleanup ();
        }

        // Code ported from KWin present windows effect
        // https://projects.kde.org/projects/kde/kde-workspace/repository/revisions/master/entry/kwin/effects/presentwindows/presentwindows.cpp

        public struct TilableWindow {
#if HAS_MUTTER45
            Mtk.Rectangle rect;
#else
            Meta.Rectangle rect;
#endif
            unowned WindowClone id;
        }

#if HAS_MUTTER45
        public static List<TilableWindow?> calculate_grid_placement (Mtk.Rectangle area, List<TilableWindow?> windows) {
#else
        public static List<TilableWindow?> calculate_grid_placement (Meta.Rectangle area, List<TilableWindow?> windows) {
#endif
            uint window_count = windows.length ();
            int columns = (int)Math.ceil (Math.sqrt (window_count));
            int rows = (int)Math.ceil (window_count / (double)columns);

            // Assign slots
            int slot_width = area.width / columns;
            int slot_height = area.height / rows;

            var result = new List<TilableWindow?> ();

            // see how many windows we have on the last row
            int without_over = columns * (rows - 1);
            int left_over = (int)window_count - without_over;
            int x_over_compensation = (columns - left_over) * slot_width / 2;

            for (int i = 0; i < window_count; i++) {
                var window = windows.nth (i).data;
                var rect = window.rect;

                // Work out where the slot is
                const int SLOT_PADDING = 10;
#if HAS_MUTTER45
                Mtk.Rectangle target = {
#else
                Meta.Rectangle target = {
#endif
                    area.x + (i % columns) * slot_width + SLOT_PADDING,
                    area.y + (i / columns) * slot_height + SLOT_PADDING,
                    slot_width - SLOT_PADDING * 2,
                    slot_height - SLOT_PADDING * 2
                };

                float width_ratio = target.width / (float)rect.width;
                float height_ratio = target.height / (float)rect.height;
                bool should_center_vertically = width_ratio < height_ratio;

                float scale = should_center_vertically ? width_ratio : height_ratio;
                if (should_center_vertically) {
                    // Center vertically
                    target.y += (target.height - (int)(rect.height * scale)) / 2;
                    target.height = (int)Math.floorf (rect.height * scale);
                } else {
                    // Center horizontally
                    target.x += (target.width - (int)(rect.width * scale)) / 2;
                    target.width = (int)Math.floorf (rect.width * scale);
                }

                // Don't scale the windows too much
                if (scale > 1.0) {
                    target = {
                        target.x + target.width / 2 - rect.width / 2,
                        target.y + target.height / 2 - rect.height / 2,
                        rect.width,
                        rect.height
                    };
                }

                // put the last row in the center, if necessary
                if (left_over != columns && i >= without_over) {
                    target.x += x_over_compensation;
                }

                result.prepend ({ target, window.id });
            }

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
         * Multiplies an integer by a floating scaling factor, and then
         * returns the result rounded to the nearest integer
         */
        public static int scale_to_int (int value, float scale_factor) {
            return (int) (Math.round ((float)value * scale_factor));
        }

        private static Gtk.StyleContext selection_style_context = null;
        public static Gdk.RGBA get_theme_accent_color () {
            if (selection_style_context == null) {
                var label_widget_path = new Gtk.WidgetPath ();
                label_widget_path.append_type (GLib.Type.from_name ("label"));
                label_widget_path.iter_set_object_name (-1, "selection");

                selection_style_context = new Gtk.StyleContext ();
                selection_style_context.set_path (label_widget_path);
            }

            return (Gdk.RGBA) selection_style_context.get_property (
                Gtk.STYLE_PROPERTY_BACKGROUND_COLOR,
                Gtk.StateFlags.NORMAL
            );
        }

        /**
         * Returns the workspaces geometry following the only_on_primary settings.
         */
#if HAS_MUTTER45
        public static Mtk.Rectangle get_workspaces_geometry (Meta.Display display) {
#else
        public static Meta.Rectangle get_workspaces_geometry (Meta.Display display) {
#endif
            if (InternalUtils.workspaces_only_on_primary ()) {
                var primary = display.get_primary_monitor ();
                return display.get_monitor_geometry (primary);
            } else {
                float screen_width, screen_height;
                display.get_size (out screen_width, out screen_height);
                return { 0, 0, (int) screen_width, (int) screen_height };
            }
        }
    }
}
