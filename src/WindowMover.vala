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
    private HashTable<Meta.Window, uint> pending_fullscreen_sources;

    public WindowMover (Meta.Display display, WindowListener window_listener) {
        Object (display: display, window_listener: window_listener);
    }

    construct {
        behavior_settings = new Settings ("io.elementary.desktop.wm.behavior");
        old_workspaces = new HashTable<Meta.Window, int> (null, null);
        pending_fullscreen_sources = new HashTable<Meta.Window, uint> (null, null);

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

        cancel_pending_fullscreen_move (window);

        var source_id = Idle.add (() => {
            pending_fullscreen_sources.remove (window);

            if (window.fullscreen) {
                move_window_to_next_ws (window, false);
            } else {
                move_window_to_old_ws (window, false);
            }

            return Source.REMOVE;
        });

        pending_fullscreen_sources[window] = source_id;
    }

    private void cancel_pending_fullscreen_move (Meta.Window window) {
        if (!pending_fullscreen_sources.contains (window)) {
            return;
        }

        var source_id = pending_fullscreen_sources.get (window);

        Source.remove (source_id);
        pending_fullscreen_sources.remove (window);
    }

    private uint get_activation_time (Meta.Window window) {
        var user_time = window.get_user_time ();
        if (user_time != 0) {
            return user_time;
        }

        return display.get_current_time_roundtrip ();
    }

    private void on_window_unmanaged (Meta.Window window) {
        cancel_pending_fullscreen_move (window);
        move_window_to_old_ws (window);
    }

    private void move_window_to_next_ws (Meta.Window window, bool focus_window = true) {
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
        var time = get_activation_time (window);
        if (focus_window) {
            new_ws.activate_with_focus (window, time);
        } else {
            new_ws.activate (time);
        }

        if (!(window in old_workspaces)) {
            window.unmanaged.connect (on_window_unmanaged);
        }

        old_workspaces[window] = old_ws_index;
    }

    private void move_window_to_old_ws (Meta.Window window, bool focus_window = true) {
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
            uint time = get_activation_time (window);
            unowned var old_ws = workspace_manager.get_workspace_by_index (old_ws_index);
            window.change_workspace (old_ws);
            if (focus_window) {
                old_ws.activate_with_focus (window, time);
            } else {
                old_ws.activate (time);
            }
        }

        old_workspaces.remove (window);

        window.unmanaged.disconnect (on_window_unmanaged);
    }
}
