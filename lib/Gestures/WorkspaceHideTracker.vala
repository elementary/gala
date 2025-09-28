/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.WorkspaceHideTracker : Object, GestureTarget {
    public signal double compute_progress (Meta.Workspace workspace);
    public signal void switching_workspace_progress_updated (double new_progress);
    public signal void window_state_changed_progress_updated (double new_progress);

    //we don't want to hold a strong reference to the actor because we might've been added to it which would form a reference cycle
    private weak Clutter.Actor? _actor;
    public Clutter.Actor? actor { get { return _actor; }}
    public Meta.Display display { private get; construct; }

    private double switch_workspace_progress = 0.0;
    private double[] workspace_hide_progress_cache = {};

    public WorkspaceHideTracker (Meta.Display display, Clutter.Actor actor) {
        Object (display: display);
        _actor = actor;
    }

    construct {
        display.list_all_windows ().foreach (setup_window);
        display.window_created.connect (setup_window);

        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (recalculate_all_workspaces);

        unowned var workspace_manager = display.get_workspace_manager ();
        workspace_manager.workspace_added.connect (recalculate_all_workspaces);
        workspace_manager.workspace_removed.connect (recalculate_all_workspaces);

        recalculate_all_workspaces ();
    }

    private void setup_window (Meta.Window window) {
        window.notify["window-type"].connect (on_window_type_changed);

        if (!Utils.get_window_is_normal (window)) {
            return;
        }

        if (window.on_all_workspaces) {
            recalculate_all_workspaces ();
        } else {
            recalculate_workspace (window);
        }

        window.position_changed.connect (recalculate_workspace);
        window.size_changed.connect (recalculate_workspace);
        window.workspace_changed.connect (recalculate_all_workspaces);
        window.focused.connect (recalculate_workspace);
        window.notify["on-all-workspaces"].connect (recalculate_all_workspaces);
        window.notify["fullscreen"].connect (recalculate_workspace_pspec);
        window.notify["minimized"].connect (recalculate_workspace_pspec);
        window.notify["above"].connect (recalculate_workspace_pspec);
        window.unmanaged.connect (recalculate_workspace);
    }

    private void on_window_type_changed (Object obj, ParamSpec pspec) {
        var window = (Meta.Window) obj;

        window.notify["window-type"].disconnect (on_window_type_changed);
        window.position_changed.disconnect (recalculate_workspace);
        window.size_changed.disconnect (recalculate_workspace);
        window.workspace_changed.disconnect (recalculate_all_workspaces);
        window.focused.disconnect (recalculate_workspace);
        window.notify["on-all-workspaces"].disconnect (recalculate_all_workspaces);
        window.notify["fullscreen"].disconnect (recalculate_workspace_pspec);
        window.notify["minimized"].disconnect (recalculate_workspace_pspec);
        window.notify["above"].disconnect (recalculate_workspace_pspec);
        window.unmanaged.disconnect (recalculate_workspace);

        setup_window (window);
    }

    public override void propagate (UpdateType update_type, GestureAction action, double progress) {
        if (action != SWITCH_WORKSPACE || update_type == COMMIT) {
            return;
        }

        switch_workspace_progress = progress.abs ();
        switching_workspace_progress_updated (get_hidden_progress ());
    }

    private double get_hidden_progress () {
        var n_workspaces = workspace_hide_progress_cache.length;

        var left_workspace = int.max ((int) Math.floor (switch_workspace_progress), 0);
        var right_workspace = int.min ((int) Math.ceil (switch_workspace_progress), n_workspaces - 1);

        var relative_progress = switch_workspace_progress - left_workspace;

        return (
            workspace_hide_progress_cache[left_workspace] * (1 - relative_progress) +
            workspace_hide_progress_cache[right_workspace] * relative_progress
        );
    }

    private void recalculate_all_workspaces () {
        unowned var workspace_manager = display.get_workspace_manager ();
        workspace_hide_progress_cache = new double[workspace_manager.n_workspaces];
        foreach (unowned var workspace in workspace_manager.get_workspaces ()) {
            internal_recalculate_workspace (workspace, false);
        }

        window_state_changed_progress_updated (get_hidden_progress ());
    }

    private void internal_recalculate_workspace (Meta.Workspace? workspace, bool send_signal) {
        if (workspace == null || workspace.workspace_index >= workspace_hide_progress_cache.length) {
            return;
        }

        workspace_hide_progress_cache[workspace.workspace_index] = compute_progress (workspace);

        if (send_signal) {
            window_state_changed_progress_updated (get_hidden_progress ());
        }
    }

    private void recalculate_workspace (Meta.Window window) {
        internal_recalculate_workspace (window.get_workspace (), true);
    }

    private void recalculate_workspace_pspec (Object obj, ParamSpec pspec) {
        internal_recalculate_workspace (((Meta.Window) obj).get_workspace (), true);
    }
}
