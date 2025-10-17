/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

private class GridPosition : Object {
    public Meta.Window window;
    public uint row;
    public uint column;
    public uint width;
    public uint height;

    public GridPosition (Meta.Window window, uint row, uint column, uint width, uint height) {
        this.window = window;
        this.row = row;
        this.column = column;
        this.width = width;
        this.height = height;
    }
}

public class Gala.MetaStrategy : Object, TileStrategy {
    private static uint latest_seen_window = 0;

    public HashTable<Meta.Window, Mtk.Rectangle?> tile (ListModel windows, Mtk.Rectangle area) {
        if (area.height == 0 || windows.get_n_items () == 0) {
            return new HashTable<Meta.Window, Mtk.Rectangle?> (null, null);
        }

        var sorted_windows = new Gee.ArrayList<Meta.Window> ();
        for (uint i = 0; i < windows.get_n_items (); i++) {
            var window = (Meta.Window) windows.get_item (i);
            sorted_windows.add (window);
        }

        Gee.List<Meta.Window> prefer_horizontal;
        Gee.List<Meta.Window> prefer_vertical;
        split_and_sort_windows (
            sorted_windows, out prefer_horizontal, out prefer_vertical,
            (double) area.width / (double) area.height
        );

        var grid_positions = calculate_grid (sorted_windows, prefer_horizontal, prefer_vertical);

        var placed_windows = fill_area (grid_positions, area);

        //  center_area (placed_windows, area);

        //  maybe_tile_windows (placed_windows, area);

        //  foreach (var window in sorted_windows) {
        //      if (!placed_windows.contains (window) && window.get_stable_sequence () > latest_seen_window) {
        //          latest_seen_window = window.get_stable_sequence ();
        //          var has_focus = window.has_focus ();
        //          window.change_workspace (window.get_workspace ().get_neighbor (RIGHT));
        //          if (has_focus) {
        //              window.activate (Meta.CURRENT_TIME);
        //          }
        //      }
        //  }

        return placed_windows;
    }

    private void split_and_sort_windows (
        Gee.List<Meta.Window> windows,
        out Gee.List<Meta.Window> prefer_horizontal,
        out Gee.List<Meta.Window> prefer_vertical,
        double for_aspect_ratio
    ) {
        prefer_horizontal = new Gee.ArrayList<Meta.Window> ();
        prefer_vertical = new Gee.ArrayList<Meta.Window> ();

        foreach (var window in windows) {
            var rect = window.get_frame_rect ();

            if (rect.height == 0) {
                continue;
            }

            var aspect_ratio = (double) rect.width / (double) rect.height;
            //  if ((aspect_ratio - for_aspect_ratio).abs () < 0.5) {
            //      continue;
            //  }

            if (aspect_ratio > for_aspect_ratio) {
                prefer_horizontal.add (window);
            } else {
                prefer_vertical.add (window);
            }
        }

        windows.remove_all (prefer_horizontal);
        windows.remove_all (prefer_vertical);
    }

    private Gee.List<GridPosition> calculate_grid (
        Gee.List<Meta.Window> windows,
        Gee.List<Meta.Window> prefer_horizontal,
        Gee.List<Meta.Window> prefer_vertical
    ) {
        var grid_positions = new Gee.ArrayList<GridPosition> ();

        if (!prefer_horizontal.is_empty) {
            uint current_row = 0;

            var width = int.max (windows.size, 1);
            foreach (var window in prefer_horizontal) {
                grid_positions.add (new GridPosition (window, current_row++, 0, width, 1));
            }

            uint current_column = 0;
            while (!windows.is_empty) {
                var window = windows.remove_at (0);
                grid_positions.add (new GridPosition (window, current_row, current_column++, 1, 1));
            }
        }

        assert_true (prefer_horizontal.is_empty || windows.is_empty);
        assert_true (windows.is_empty || grid_positions.is_empty);

        if (!prefer_vertical.is_empty) {
            uint n_rows = 1;
            uint current_column = 0;
            foreach (var position in grid_positions) {
                n_rows = uint.max (n_rows, position.row + position.height);
                current_column = uint.max (current_column, position.column + position.width);
            }

            var height = uint.max (windows.size, n_rows);
            foreach (var window in prefer_vertical) {
                grid_positions.add (new GridPosition (window, 0, current_column++, 1, height));
            }

            uint current_row = 0;
            while (!windows.is_empty) {
                var window = windows.remove_at (0);
                grid_positions.add (new GridPosition (window, current_row++, current_column, 1, 1));
            }
        }

        if (prefer_vertical.size > 0 || prefer_horizontal.size > 0) {
            assert_true (windows.is_empty);
            return grid_positions;
        }

        // All windows have about the aspect ratio of the area, so we create a grid as square as possible
        var grid_size = Math.ceil (Math.sqrt (windows.size));

        int i = 0;
        foreach (var window in windows) {
            grid_positions.add (new GridPosition (window, (uint) (i / grid_size), (uint) (i % grid_size), 1, 1));
            i++;
        }

        return grid_positions;
    }

    private HashTable<Meta.Window, Mtk.Rectangle?> fill_area (Gee.List<GridPosition> grid_positions, Mtk.Rectangle area) {
        var temporary_grid = new Gee.LinkedList<GridPosition> ();
        temporary_grid.add_all (grid_positions);

        uint n_columns = 0;
        uint n_rows = 0;
        foreach (var position in grid_positions) {
            n_columns = uint.max (n_columns, position.column + position.width);
            n_rows = uint.max (n_rows, position.row + position.height);
        }

        int[] column_widths = new int[n_columns];
        int[] row_heights = new int[n_rows];

        int index = 0;
        int size = 1;
        while (!temporary_grid.is_empty) {
            var position = temporary_grid[index];

            if (position.width == 0 || position.height == 0) {
                temporary_grid.remove (position);
                continue;
            }

            var rect = position.window.get_frame_rect ();

            if (position.width == size) {
                int current_size = 0;
                for (uint i = position.column; i < position.column + position.width; i++) {
                    current_size += column_widths[i];
                }

                if (current_size < rect.width) {
                    var additional = (int) Math.ceil ((rect.width - current_size) / position.width);
                    for (uint i = position.column; i < position.column + position.width; i++) {
                        column_widths[i] += additional;
                    }
                }
            }

            if (position.height == size) {
                int current_size = 0;
                for (uint i = position.row; i < position.row + position.height; i++) {
                    current_size += row_heights[i];
                }

                if (current_size < rect.height) {
                    var additional = (int) Math.ceil ((rect.height - current_size) / position.height);
                    for (uint i = position.row; i < position.row + position.height; i++) {
                        row_heights[i] += additional;
                    }
                }
            }

            if (position.width <= size && position.height <= size) {
                temporary_grid.remove (position);
                index--;
            }

            index++;
            if (index >= temporary_grid.size) {
                index = 0;
                size++;
            }
        }

        var placed_windows = new HashTable<Meta.Window, Mtk.Rectangle?> (null, null);
        foreach (var position in grid_positions) {
            int x = 0;
            for (uint i = 0; i < position.column; i++) {
                x += column_widths[i];
            }

            int y = 0;
            for (uint i = 0; i < position.row; i++) {
                y += row_heights[i];
            }

            var window_rect = position.window.get_frame_rect ();
            window_rect.x = x;
            window_rect.y = y;

            placed_windows[position.window] = window_rect;
        }

        return placed_windows;
    }

    private void center_area (HashTable<Meta.Window, Mtk.Rectangle?> windows, Mtk.Rectangle area) {
        var max_x = 0;
        var max_y = 0;
        foreach (var rect in windows.get_values ()) {
            max_x = rect.x + rect.width > max_x ? rect.x + rect.width : max_x;
            max_y = rect.y + rect.height > max_y ? rect.y + rect.height : max_y;
        }

        var x_offset = (area.width - (max_x - area.x)) / 2;
        var y_offset = (area.height - (max_y - area.y)) / 2;

        foreach (var window in windows.get_keys ()) {
            var rect = windows[window];
            rect.x += x_offset;
            rect.y += y_offset;
            windows[window] = rect;
        }
    }

    private void maybe_tile_windows (HashTable<Meta.Window, Mtk.Rectangle?> windows, Mtk.Rectangle area) {
        var used_area = 0;
        foreach (var rect in windows.get_values ()) {
            used_area += rect.area ();
        }

        if (used_area > area.area () * 0.8) {
            tile_windows (windows, area);
        }
    }

    private void tile_windows (HashTable<Meta.Window, Mtk.Rectangle?> windows, Mtk.Rectangle area) {
        var min_x = 0;
        var min_y = 0;
        int max_y = 0;
        var row_ys = new Gee.LinkedList<int> ();

        foreach (var rect in windows.get_values ()) {
            min_x = rect.x < min_x ? rect.x : min_x;
            min_y = rect.y < min_y ? rect.y : min_y;
            max_y = rect.y > max_y ? rect.y : max_y;

            if (!(rect.y in row_ys)) {
                row_ys.add (rect.y);
            }
        }

        row_ys.sort ();

        int[] max_x_per_row = new int[row_ys.size];
        foreach (var rect in windows.get_values ()) {
            var row_index = row_ys.index_of (rect.y);
            max_x_per_row[row_index] = rect.x > max_x_per_row[row_index] ? rect.x : max_x_per_row[row_index];
        }

        foreach (var window in windows.get_keys ()) {
            var rect = windows[window];

            // These don't adjust x,y so do them first because we need x,y for the matching
            if (rect.y == max_y) {
                rect.height += (area.y + area.height) - (max_y + rect.height);
            }

            var row_index = row_ys.index_of (rect.y);
            if (rect.x == max_x_per_row[row_index]) {
                rect.width += (area.x + area.width) - (rect.x + rect.width);
            }

            // Now we can adjust x,y as well
            if (rect.x == min_x) {
                rect.width += area.x - min_x;
                rect.x = area.x;
            }

            if (rect.y == min_y) {
                rect.height += area.y - min_y;
                rect.y = area.y;
            }

            windows[window] = rect;
        }
    }
}
