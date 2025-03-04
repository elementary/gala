/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Gala.StaticWindowContainer : ActorTarget {
    private static StaticWindowContainer? instance;

    public static StaticWindowContainer init (Meta.Display display, GestureController workspace_controller) {
        instance = new StaticWindowContainer (display, workspace_controller);
        return instance;
    }

    public static StaticWindowContainer get_instance () {
        return instance;
    }

    public signal void window_changed (Meta.Window window, bool is_static);

    public Meta.Display display { get; construct; }
    public GestureController workspace_controller { get; construct; }

    private Meta.Window? grabbed_window;
    private Meta.Window? moving_window;

    private StaticWindowContainer (Meta.Display display, GestureController workspace_controller) {
        Object (display: display, workspace_controller: workspace_controller);
    }

    construct {
        display.grab_op_begin.connect (on_grab_op_begin);
        display.grab_op_end.connect (on_grab_op_end);

        unowned var window_listener = WindowListener.get_default ();
        window_listener.window_on_all_workspaces.connect (check_window_changed);
        window_listener.window_no_longer_on_all_workspaces.connect (check_window_changed);
    }

    private void on_grab_op_begin (Meta.Window window, Meta.GrabOp op) {
        if (op != MOVING) {
            return;
        }

        grabbed_window = window;
        check_window_changed (window);
    }

    private void on_grab_op_end (Meta.Window window, Meta.GrabOp op) {
        grabbed_window = null;
        check_window_changed (window);
    }

    public void move_window (Meta.Window window, int workspace_index) {
        start_move (window);
        workspace_controller.goto (-workspace_index);
    }

    private void start_move (Meta.Window window) {
        moving_window = window;
        check_window_changed (window);
    }

    private void check_window_changed (Meta.Window window) {
        var is_static = (window == grabbed_window || window == moving_window || window.on_all_workspaces) &&
            !ShellClientsManager.get_instance ().is_positioned_window (window);

        Clutter.Actor? clone = null;
        for (var child = get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (((StaticWindowClone) child).window == window) {
                clone = child;
                break;
            }
        }

        if (!is_static && clone != null) {
            remove_child (clone);
        } else if (is_static && clone == null) {
            add_child (new StaticWindowClone (window));
        }

        window_changed (window, is_static);
    }

    public override void start_progress (GestureAction action) {
        if (action == SWITCH_WORKSPACE && (bool) workspace_controller.action_info && display.focus_window != null) {
            start_move (display.focus_window);

            if (Utils.get_n_windows (moving_window.get_workspace (), true, moving_window) == 0) {
                workspace_controller.overshoot_lower_clamp++;
            }
        }

        if (action == SWITCH_WORKSPACE && moving_window != null) {
            WorkspaceManager.get_default ().freeze_remove ();
        }
    }

    public override void commit_progress (GestureAction action, double to) {
        if (action == SWITCH_WORKSPACE && moving_window != null) {
            unowned var workspace = display.get_workspace_manager ().get_workspace_by_index ((int) (-to));
            moving_window.change_workspace (workspace);
            workspace.activate_with_focus (moving_window, Meta.CURRENT_TIME);
        }
    }

    public override void end_progress (GestureAction action) {
        if (action == SWITCH_WORKSPACE && moving_window != null) {
            var window = moving_window;
            moving_window = null;
            check_window_changed (window);

            display.get_workspace_manager ().notify_property ("n-workspaces"); // Recalculate clamps for the controller

            WorkspaceManager.get_default ().thaw_remove ();
        }
    }
}
