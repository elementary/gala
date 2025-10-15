/*
 * Copyright 2024-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PanelWindow : ShellWindow, RootTarget {
    private static HashTable<Meta.Window, Meta.Strut?> window_struts = new HashTable<Meta.Window, Meta.Strut?> (null, null);

    public Clutter.Actor? actor { get { return (Clutter.Actor) window.get_compositor_private (); } }
    public WindowManager wm { get; construct; }
    public Pantheon.Desktop.Anchor anchor { get; construct set; }

    private Pantheon.Desktop.HideMode _hide_mode;
    public Pantheon.Desktop.HideMode hide_mode {
        get {
            return _hide_mode;
        }
        set {
            _hide_mode = value;

            if (value == NEVER) {
                make_exclusive ();
            } else {
                unmake_exclusive ();
            }
        }
    }

    public bool visible_in_multitasking_view { get; private set; default = false; }

    private GestureController user_gesture_controller;
    private HideTracker hide_tracker;
    private GestureController workspace_gesture_controller;
    private WorkspaceHideTracker workspace_hide_tracker;

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

        user_gesture_controller = new GestureController (CUSTOM, wm) {
            progress = 1.0
        };

        hide_tracker = new HideTracker (wm.get_display (), this);
        hide_tracker.hide.connect (hide);
        hide_tracker.show.connect (show);

        workspace_gesture_controller = new GestureController (CUSTOM, wm);

        workspace_hide_tracker = new WorkspaceHideTracker (window.display, update_overlap);
        workspace_hide_tracker.switching_workspace_progress_updated.connect ((value) => workspace_gesture_controller.progress = value);
        workspace_hide_tracker.window_state_changed_progress_updated.connect (workspace_gesture_controller.goto);

        add_gesture_controller (user_gesture_controller);
        add_gesture_controller (workspace_gesture_controller);
    }

    public void request_visible_in_multitasking_view () {
        visible_in_multitasking_view = true;
        actor.add_action (new DragDropAction (DESTINATION, "multitaskingview-window"));
    }

    protected override void update_target () {
        base.update_target ();
        workspace_hide_tracker.recalculate_all_workspaces ();
    }

    protected override double get_hidden_progress () {
        var user_workspace_hidden_progress = double.min (
            user_gesture_controller.progress,
            workspace_gesture_controller.progress
        );

        if (visible_in_multitasking_view) {
            return double.min (user_workspace_hidden_progress, 1 - base.get_hidden_progress ());
        } else {
            return double.max (user_workspace_hidden_progress, base.get_hidden_progress ());
        }
    }

    public override void propagate (GestureTarget.UpdateType update_type, GestureAction action, double progress) {
        workspace_hide_tracker.update (update_type, action, progress);
        base.propagate (update_type, action, progress);
    }

    private void hide () {
        user_gesture_controller.goto (1);
    }

    private void show () {
        user_gesture_controller.goto (0);
    }

    private bool update_overlap (Meta.Workspace workspace) {
        var overlap = false;
        var focus_overlap = false;
        var focus_maximized_overlap = false;
        var fullscreen_overlap = window.display.get_monitor_in_fullscreen (window.get_monitor ());

        Meta.Window? normal_mru_window, any_mru_window;
        normal_mru_window = InternalUtils.get_mru_window (workspace, out any_mru_window);

        foreach (var window in workspace.list_windows ()) {
            if (window == this.window) {
                continue;
            }

            if (window.minimized) {
                continue;
            }

            var type = window.get_window_type ();
            if (type == DESKTOP || type == DOCK || type == MENU || type == SPLASHSCREEN) {
                continue;
            }

            if (!get_custom_window_rect ().overlap (window.get_frame_rect ())) {
                continue;
            }

            overlap = true;

            if (window != normal_mru_window && window != any_mru_window) {
                continue;
            }

            focus_overlap = true;
            focus_maximized_overlap = window.maximized_vertically;
        }

        switch (hide_mode) {
            case MAXIMIZED_FOCUS_WINDOW: return focus_maximized_overlap;
            case OVERLAPPING_FOCUS_WINDOW: return focus_overlap;
            case OVERLAPPING_WINDOW: return overlap;
            case ALWAYS: return true;
            case NEVER: return fullscreen_overlap;
        }

        return false;
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
