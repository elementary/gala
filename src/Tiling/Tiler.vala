/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Gala.TileStrategy : Object {
    public abstract HashTable<Meta.Window, Mtk.Rectangle?> tile (ListModel windows, Mtk.Rectangle area);
}

public class Gala.Tiler : Object {
    public Meta.Display display { get; construct; }
    public int monitor { get; construct; }
    public Meta.Workspace workspace { get; construct; }
    public TileStrategy strategy { get; construct set; }

    private WindowListModel windows;

    private uint tile_windows_id = 0;

    public Tiler (Meta.Display display, int monitor, Meta.Workspace workspace) {
        Object (display: display, monitor: monitor, workspace: workspace, strategy: new MetaStrategy ());
    }

    construct {
        windows = new WindowListModel (display, NONE, true, monitor, workspace);
        windows.items_changed.connect (queue_tile_windows);

        queue_tile_windows ();
    }

    public void queue_tile_windows () {
        if (tile_windows_id == 0) {
            var laters = display.get_compositor ().get_laters ();
            tile_windows_id = laters.add (BEFORE_REDRAW, tile_windows);
        }
    }

    private bool tile_windows () {
        var area = workspace.get_work_area_for_monitor (monitor);

        var tiled_windows = strategy.tile (windows, area);

        for (uint i = 0; i < windows.get_n_items (); i++) {
            var window = (Meta.Window) windows.get_item (i);

            if (!tiled_windows.contains (window)) {
                //  window.change_workspace_by_index (workspace.index () + 1, true);
                continue;
            }

            var current_rect = window.get_frame_rect ();
            var new_rect = tiled_windows[window];

            if (!new_rect.equal (current_rect)) {
                window.move_resize_frame (false, new_rect.x, new_rect.y, new_rect.width, new_rect.height);
            }
        }

        tile_windows_id = 0;
        return Source.REMOVE;
    }
}
