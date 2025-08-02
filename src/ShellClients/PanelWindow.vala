/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PanelWindow : ShellWindow, RootTarget {
    private static HashTable<Meta.Window, Meta.Strut?> window_struts = new HashTable<Meta.Window, Meta.Strut?> (null, null);

    public WindowManager wm { get; construct; }
    public Pantheon.Desktop.Anchor anchor { get; construct set; }

    public Pantheon.Desktop.HideMode hide_mode {
        get {
            return hide_tracker.hide_mode;
        }
        set {
            hide_tracker.hide_mode = value;

            if (value == NEVER) {
                make_exclusive ();
            } else {
                unmake_exclusive ();
            }
        }
    }

    private GestureController gesture_controller;
    private HideTracker hide_tracker;

    public PanelWindow (WindowManager wm, Meta.Window window, Pantheon.Desktop.Anchor anchor) {
        Object (wm: wm, anchor: anchor, window: window, position: Position.from_anchor (anchor));
    }

    construct {
        window.unmanaging.connect (() => {
            if (window_struts.remove (window)) {
                update_struts ();
            }
        });

        notify["anchor"].connect (() => position = Position.from_anchor (anchor));

        unowned var workspace_manager = window.display.get_workspace_manager ();
        workspace_manager.workspace_added.connect (update_strut);
        workspace_manager.workspace_removed.connect (update_strut);

        window.size_changed.connect (update_strut);
        window.position_changed.connect (update_strut);
        notify["width"].connect (update_strut);
        notify["height"].connect (update_strut);

        gesture_controller = new GestureController (CUSTOM, wm);
        add_gesture_controller (gesture_controller);

        hide_tracker = new HideTracker (wm.get_display (), this);
        hide_tracker.hide.connect (hide);
        hide_tracker.show.connect (show);
    }

    public void request_visible_in_multitasking_view () {
        visible_in_multitasking_view = true;
        actor.add_action (new DragDropAction (DESTINATION, "multitaskingview-window"));
    }

    private void hide () {
        gesture_controller.goto (1);
    }

    private void show () {
        gesture_controller.goto (0);
    }

    private void make_exclusive () {
        update_strut ();
    }

    private void update_strut () {
        if (hide_mode != NEVER) {
            return;
        }

        var rect = get_custom_window_rect ();

        Meta.Strut strut = {
            rect,
            side_from_anchor (anchor)
        };

        window_struts[window] = strut;

        update_struts ();
    }

    private void update_struts () {
        var list = new SList<Meta.Strut?> ();

        foreach (var window_strut in window_struts.get_values ()) {
            list.append (window_strut);
        }

        foreach (var workspace in wm.get_display ().get_workspace_manager ().get_workspaces ()) {
            workspace.set_builtin_struts (list);
        }
    }

    private void unmake_exclusive () {
        if (window in window_struts) {
            window_struts.remove (window);
            update_struts ();
        }
    }

    private Meta.Side side_from_anchor (Pantheon.Desktop.Anchor anchor) {
        switch (anchor) {
            case BOTTOM:
                return BOTTOM;

            case LEFT:
                return LEFT;

            case RIGHT:
                return RIGHT;

            default:
                return TOP;
        }
    }
}
