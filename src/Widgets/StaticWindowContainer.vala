/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Gala.StaticWindowContainer : ActorTarget {
    private static GLib.Once<StaticWindowContainer> instance;
    public static StaticWindowContainer get_instance (Meta.Display display) {
        return instance.once (() => { return new StaticWindowContainer (display); });
    }

    public signal void window_changed (Meta.Window window, bool is_static);

    public Meta.Display display { get; construct; }

    public Meta.Window? grabbed_window { get; private set; }
    public Meta.Window? moving_window { get; private set; }

    private StaticWindowContainer (Meta.Display display) {
        Object (display: display);
    }

    construct {
        display.grab_op_begin.connect (on_grab_op_begin);
        display.grab_op_end.connect (on_grab_op_end);

        unowned var window_listener = WindowListener.get_default ();
        window_listener.window_on_all_workspaces.connect (on_all_workspaces_changed);
        window_listener.window_no_longer_on_all_workspaces.connect (on_all_workspaces_changed);
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

    private void on_all_workspaces_changed (Meta.Window window) {
        // We have to wait for shell clients here
        Idle.add (() => {
            check_window_changed (window);
            return Source.REMOVE;
        });
    }

    public void notify_window_moving (Meta.Window window) {
        moving_window = window;
        check_window_changed (window);
    }

    public void notify_move_ended () {
        if (moving_window == null) {
            return;
        }

        var window = moving_window;
        moving_window = null;
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
}
