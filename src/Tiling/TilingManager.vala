/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.TilingManager : Object {
    public Meta.Display display { get; construct; }

    private Gee.List<Gee.List<Tiler>> tilers = new Gee.ArrayList<Gee.List<Tiler>> ();

    public TilingManager (Meta.Display display) {
        Object (display: display);
    }

    construct {
        var workspace_manager = display.get_workspace_manager ();
        workspace_manager.workspace_added.connect (on_workspace_added);
        workspace_manager.workspace_removed.connect (on_workspace_removed);

        var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (reset_all_tilers);

        reset_all_tilers ();

        display.window_created.connect (setup_window);
    }

    private void reset_all_tilers () {
        tilers.clear ();

        var workspace_manager = display.get_workspace_manager ();
        foreach (var workspace in workspace_manager.get_workspaces ()) {
            add_tiler_for_workspace (workspace);
        }
    }

    private void on_workspace_added (int index) {
        var workspace = display.get_workspace_manager ().get_workspace_by_index (index);
        add_tiler_for_workspace (workspace);
    }

    private void add_tiler_for_workspace (Meta.Workspace workspace) {
        var ws_index = workspace.index ();

        tilers.insert (ws_index, new Gee.ArrayList<Tiler> ());

        for (int i = 0; i < display.get_n_monitors (); i++) {
            var tiler = new Tiler (display, i, workspace);
            tilers[ws_index].add (tiler);
        }
    }

    private void on_workspace_removed (int index) {
        tilers.remove_at (index);
    }

    private void setup_window (Meta.Window window) {
        window.size_changed.connect (window_changed);
        window.position_changed.connect (window_changed);
    }

    private void window_changed (Meta.Window window) {
        tilers[window.get_workspace ().index ()][window.get_monitor ()].queue_tile_windows ();
    }
}
