/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * This class handles moving windows to a new workspace when they are
 * maximized or fullscreened, depending on user settings.
 */
public class Gala.WindowMover : Object {
    public Meta.Display display { get; construct; }
    public WindowListener window_listener { get; construct; }

    private Settings behavior_settings;
    private HashTable<Meta.Window, int> old_workspaces;
    private HashTable<Meta.Window, uint> queued_moves;

    public WindowMover (Meta.Display display, WindowListener window_listener) {
        Object (display: display, window_listener: window_listener);
    }

    construct {
        behavior_settings = new Settings ("io.elementary.desktop.wm.behavior");
        old_workspaces = new HashTable<Meta.Window, int> (null, null);
        queued_moves = new HashTable<Meta.Window, uint> (null, null);

        window_listener.window_maximized_changed.connect (on_window_maximized_changed);
        window_listener.window_fullscreen_changed.connect (on_window_fullscreen_changed);
    }

    private void on_window_maximized_changed (Meta.Window window) {
        if (!behavior_settings.get_boolean ("move-maximized-workspace")) {
            return;
        }

        if (window.maximized_horizontally) {
            move_window_to_next_ws (window);
        } else {
            move_window_to_old_ws (window);
        }
    }

    private void on_window_fullscreen_changed (Meta.Window window) {
        if (!behavior_settings.get_boolean ("move-fullscreened-workspace")) {
            return;
        }

        if (window.fullscreen) {
            /* Firefox (while playing a video) immediately unfullscreens if we move it immediately */
            queue_move_window_to_next_ws (window);
        } else {
            move_window_to_old_ws (window);
        }
    }

    private void queue_move_window_to_next_ws (Meta.Window window) {
        queued_moves[window] = Idle.add (() => {
            move_window_to_next_ws (window);
            queued_moves.remove (window);
            return Source.REMOVE;
        });
    }

    private void move_window_to_next_ws (Meta.Window window) {
        unowned var win_ws = window.get_workspace ();

        // Do nothing if the current workspace would be empty
        if (Utils.get_n_windows (win_ws) <= 1) {
            return;
        }

        // Do nothing if window is not on primary monitor
        if (!window.is_on_primary_monitor ()) {
            return;
        }

        var old_ws_index = win_ws.index ();
        var new_ws_index = old_ws_index + 1;
        InternalUtils.insert_workspace_with_window (new_ws_index, window);

        var new_ws = display.get_workspace_manager ().get_workspace_by_index (new_ws_index);
        var time = display.get_current_time ();
        new_ws.activate_with_focus (window, time);

        if (!(window in old_workspaces)) {
            window.unmanaged.connect (move_window_to_old_ws);
        }

        old_workspaces[window] = old_ws_index;
    }

    private void move_window_to_old_ws (Meta.Window window) {
        if (window in queued_moves) {
            Source.remove (queued_moves[window]);
            queued_moves.remove (window);
            return;
        }

        unowned var win_ws = window.get_workspace ();

        // Do nothing if the current workspace is populated with other windows
        if (Utils.get_n_windows (win_ws) > 1) {
            return;
        }

        if (!old_workspaces.contains (window)) {
            return;
        }

        var old_ws_index = old_workspaces.get (window);
        var new_ws_index = win_ws.index ();

        unowned var workspace_manager = display.get_workspace_manager ();
        if (new_ws_index != old_ws_index && old_ws_index < workspace_manager.get_n_workspaces ()) {
            uint time = display.get_current_time ();
            unowned var old_ws = workspace_manager.get_workspace_by_index (old_ws_index);
            window.change_workspace (old_ws);
            old_ws.activate_with_focus (window, time);
        }

        old_workspaces.remove (window);

        window.unmanaged.disconnect (move_window_to_old_ws);
    }
}
