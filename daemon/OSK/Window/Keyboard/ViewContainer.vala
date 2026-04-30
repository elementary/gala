/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.ViewContainer : Granite.Bin {
    private const int KEY_SIZE = 2;

    public ListModel view { set { update_keys (value); } }

    private Gtk.Grid grid;
    private Gtk.AspectFrame aspect_frame;

    construct {
        grid = new Gtk.Grid () {
            row_homogeneous = true,
            column_homogeneous = true,
            row_spacing = 4,
            column_spacing = 4,
        };

        aspect_frame = new Gtk.AspectFrame (0.5f, 0.5f, 1.0f, false) {
            child = grid,
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6,
        };

        child = aspect_frame;
    }

    private void update_keys (ListModel rows) {
        while (grid.get_first_child () != null) {
            grid.remove (grid.get_first_child ());
        }

        int max_row_width = 0;
        int current_row = 0;

        for (int i = 0; i < rows.get_n_items (); i++) {
            var row = (ListModel) rows.get_item (i);

            int row_width, row_height;
            attach_row (current_row, row, out row_width, out row_height);

            max_row_width = int.max (max_row_width, row_width);
            current_row += row_height;
        }

        aspect_frame.ratio = (float) max_row_width / (float) current_row;
    }

    private void attach_row (int index, ListModel row, out int row_width, out int row_height) {
        row_width = 0;
        row_height = 0;

        for (int i = 0; i < row.get_n_items (); i++) {
            var key = (Key) row.get_item (i);

            var key_button = new KeyButton () {
                key = key,
            };

            row_width += (int) (key.left_offset * KEY_SIZE);

            var width = (int) (key.width * KEY_SIZE);
            var height = (int) (key.height * KEY_SIZE);

            grid.attach (key_button, row_width, index, width, height);

            row_width += width;
            row_height = int.max (row_height, height);
        }
    }
}
