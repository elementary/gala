/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellWindow : PositionedWindow, RootTarget, GestureTarget {
    public WindowManager wm { get; construct; }
    public Clutter.Actor? actor { get { return window_actor; } }
    public bool restore_previous_x11_region { private get; set; default = false; }
    public bool visible_in_multitasking_view { get; set; default = false; }
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

            workspace_hide_tracker.recalculate_all_workspaces ();
        }
    }

    private static HashTable<Meta.Window, Meta.Strut?> window_struts = new HashTable<Meta.Window, Meta.Strut?> (null, null);

    private Meta.WindowActor window_actor;
    private double custom_progress = 0;
    private double multitasking_view_progress = 0;
    private double workspace_reveal_progress = 0;

    private int animations_ongoing = 0;

    private PropertyTarget property_target;

    private GestureController custom_gesture_controller;
    private GestureController workspace_gesture_controller;
    private HideTracker hide_tracker;
    private WorkspaceHideTracker workspace_hide_tracker;

    public ShellWindow (Meta.Window window, Position position, Variant? position_data = null) {
        base (window, position, position_data);
    }

    construct {
        window_actor = (Meta.WindowActor) window.get_compositor_private ();

        custom_gesture_controller = new GestureController (CUSTOM, wm) {
            progress = 1.0
        };
        add_gesture_controller (custom_gesture_controller);

        workspace_gesture_controller = new GestureController (CUSTOM_2, wm);
        add_gesture_controller (workspace_gesture_controller);

        hide_tracker = new HideTracker (window.display, this);
        hide_tracker.hide.connect (() => custom_gesture_controller.goto (1));
        hide_tracker.show.connect (() => custom_gesture_controller.goto (0));

        workspace_hide_tracker = new WorkspaceHideTracker (window.display, actor);
        workspace_hide_tracker.compute_progress.connect (update_overlap);
        workspace_hide_tracker.switching_workspace_progress_updated.connect ((value) => workspace_gesture_controller.progress = value);
        workspace_hide_tracker.window_state_changed_progress_updated.connect (workspace_gesture_controller.goto);

        window_actor.notify["width"].connect (update_clip);
        window_actor.notify["height"].connect (update_clip);
        window_actor.notify["translation-y"].connect (update_clip);
        notify["position"].connect (update_clip);

        window.unmanaging.connect (() => {
            if (window_struts.remove (window)) {
                update_struts ();
            }
        });

        window.size_changed.connect (update_target);
        notify["position"].connect (update_target);
        update_target ();
    }

    private void update_target () {
        property_target = new PropertyTarget (
            CUSTOM, window_actor,
            get_animation_property (),
            get_property_type (),
            calculate_value (false),
            calculate_value (true)
        );

        workspace_hide_tracker.recalculate_all_workspaces ();
    }

    private double get_hidden_progress () {
        if (visible_in_multitasking_view) {
            return double.min (double.min (custom_progress, workspace_reveal_progress), 1 - multitasking_view_progress);
        } else {
            return double.max (double.min (custom_progress, workspace_reveal_progress), multitasking_view_progress);
        }
    }

    private void update_property () {
        property_target.propagate (UPDATE, CUSTOM, get_hidden_progress ());
    }

    public override void propagate (UpdateType update_type, GestureAction action, double progress) {
        workspace_hide_tracker.propagate (update_type, action, progress);

        switch (update_type) {
            case START:
                animations_ongoing++;
                update_visibility ();
                break;

            case UPDATE:
                on_update (action, progress);
                break;

            case END:
                animations_ongoing--;
                update_visibility ();
                break;

            default:
                break;
        }
    }

    private void on_update (GestureAction action, double progress) {
        switch (action) {
            case MULTITASKING_VIEW:
                multitasking_view_progress = progress;
                break;

            case CUSTOM:
                custom_progress = progress;
                break;

            case CUSTOM_2:
                workspace_reveal_progress = progress;
                break;

            default:
                break;
        }

        update_property ();
    }

    private void update_visibility () {
        var visible = get_hidden_progress () < 0.1;
        var animating = animations_ongoing > 0;

        window_actor.visible = animating || visible;

        if (window_actor.visible) {
#if HAS_MUTTER48
            window.display.get_compositor ().disable_unredirect ();
#else
            window.display.disable_unredirect ();
#endif
        } else {
#if HAS_MUTTER48
            window.display.get_compositor ().enable_unredirect ();
#else
            window.display.enable_unredirect ();
#endif
        }

        if (!Meta.Util.is_wayland_compositor ()) {
            if (window_actor.visible) {
                Utils.x11_unset_window_pass_through (window, restore_previous_x11_region);
            } else {
                Utils.x11_set_window_pass_through (window);
            }
        }

        unowned var manager = ShellClientsManager.get_instance ();
        window.foreach_transient ((transient) => {
            if (manager.is_itself_positioned (transient)) {
                return true;
            }

            unowned var window_actor = (Meta.WindowActor) transient.get_compositor_private ();

            window_actor.visible = visible && !animating;

            return true;
        });
    }

    private string get_animation_property () {
        switch (position) {
            case TOP:
            case BOTTOM:
                return "translation-y";
            default:
                return "opacity";
        }
    }

    private Type get_property_type () {
        switch (position) {
            case TOP:
            case BOTTOM:
                return typeof (float);
            default:
                return typeof (uint);
        }
    }

    private Value calculate_value (bool hidden) {
        var custom_rect = get_custom_window_rect ();

        switch (position) {
            case TOP:
                return hidden ? -custom_rect.height : 0f;
            case BOTTOM:
                return hidden ? custom_rect.height : 0f;
            default:
                return hidden ? 0u : 255u;
        }
    }

    private void update_clip () {
        if (position != TOP && position != BOTTOM) {
            window_actor.remove_clip ();
            return;
        }

        var monitor_geom = window.display.get_monitor_geometry (window.get_monitor ());

        var y = window_actor.y + window_actor.translation_y;

        if (y + window_actor.height > monitor_geom.y + monitor_geom.height) {
            window_actor.set_clip (0, 0, window_actor.width, monitor_geom.y + monitor_geom.height - y);
        } else if (y < monitor_geom.y) {
            window_actor.set_clip (0, monitor_geom.y - y, window_actor.width, window_actor.height);
        } else {
            window_actor.remove_clip ();
        }
    }

    private double update_overlap (Meta.Workspace workspace) {
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
            case MAXIMIZED_FOCUS_WINDOW:
                return focus_maximized_overlap ? 1.0 : 0.0;

            case OVERLAPPING_FOCUS_WINDOW:
                return focus_overlap ? 1.0 : 0.0;

            case OVERLAPPING_WINDOW:
                return overlap ? 1.0 : 0.0;

            case ALWAYS:
                return 1.0;

            case NEVER:
                return fullscreen_overlap ? 1.0 : 0.0;
        }

        return 0.0;
    }

    private void make_exclusive () {
        update_strut ();
    }

    internal void update_strut () {
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

    internal void update_struts () {
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
