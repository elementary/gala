/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.HideTracker : Object {
    private const int BARRIER_OFFSET = 50; // Allow hot corner trigger
    private const int UPDATE_TIMEOUT = 200;
    private const int HIDE_DELAY = 500;

    public signal void hide ();
    public signal void show ();

    public Meta.Display display { get; construct; }
    public unowned PanelWindow panel { get; construct; }

    private Pantheon.Desktop.HideMode _hide_mode = NEVER;
    public Pantheon.Desktop.HideMode hide_mode {
        get {
            return _hide_mode;
        }
        set {
            _hide_mode = value;

            setup_barrier ();
        }
    }

    private Clutter.PanAction pan_action;

    private bool hovered = false;

    private bool overlap = false;
    private bool focus_overlap = false;
    private bool focus_maximized_overlap = false;

    private Meta.Window current_focus_window;

    private Barrier? barrier;

    private uint hide_timeout_id = 0;
    private uint update_timeout_id = 0;

    public HideTracker (Meta.Display display, PanelWindow panel) {
        Object (display: display, panel: panel);
    }

    ~HideTracker () {
        if (hide_timeout_id != 0) {
            Source.remove (hide_timeout_id);
        }
    }

    construct {
        // Can't be local otherwise we get a memory leak :(
        // See https://gitlab.gnome.org/GNOME/vala/-/issues/1548
        current_focus_window = display.focus_window;
        track_focus_window (current_focus_window);
        display.notify["focus-window"].connect (() => {
            untrack_focus_window (current_focus_window);
            current_focus_window = display.focus_window;
            track_focus_window (current_focus_window);
        });

        display.window_created.connect ((window) => {
            schedule_update ();
            window.unmanaged.connect (schedule_update);
        });

        var cursor_tracker = display.get_cursor_tracker ();
        cursor_tracker.position_invalidated.connect (() => {
#if HAS_MUTTER45
            var has_pointer = panel.window.has_pointer ();
#else
            var has_pointer = window_has_pointer ();
#endif

            if (hovered != has_pointer) {
                hovered = has_pointer;
                schedule_update ();
            }
        });

        display.get_workspace_manager ().active_workspace_changed.connect (schedule_update);

        pan_action = new Clutter.PanAction () {
            n_touch_points = 1,
            pan_axis = X_AXIS
        };
        pan_action.gesture_begin.connect (check_valid_gesture);
        pan_action.pan.connect (on_pan);

        display.get_stage ().add_action_full ("panel-swipe-gesture", CAPTURE, pan_action);
    }

    //Can be removed with mutter > 45
    private bool window_has_pointer () {
        var cursor_tracker = display.get_cursor_tracker ();
        Graphene.Point pointer_pos;
        cursor_tracker.get_pointer (out pointer_pos, null);

        var window_rect = panel.get_custom_window_rect ();
        Graphene.Rect graphene_window_rect = {
            {
                window_rect.x,
                window_rect.y
            },
            {
                window_rect.width,
                window_rect.height
            }
        };
        return graphene_window_rect.contains_point (pointer_pos);
    }

    private void track_focus_window (Meta.Window? window) {
        if (window == null) {
            return;
        }

        window.position_changed.connect (schedule_update);
        window.size_changed.connect (schedule_update);
        schedule_update ();
    }

    private void untrack_focus_window (Meta.Window? window) {
        if (window == null) {
            return;
        }

        window.position_changed.disconnect (schedule_update);
        window.size_changed.disconnect (schedule_update);
        schedule_update ();
    }

    public void schedule_update () {
        if (update_timeout_id != 0) {
            return;
        }

        update_timeout_id = Timeout.add (UPDATE_TIMEOUT, () => {
            update_overlap ();
            update_timeout_id = 0;
            return Source.REMOVE;
        });
    }

    private void update_overlap () {
        overlap = false;
        focus_overlap = false;
        focus_maximized_overlap = false;

        foreach (var window in display.get_workspace_manager ().get_active_workspace ().list_windows ()) {
            if (window == panel.window) {
                continue;
            }

            if (window.minimized) {
                continue;
            }

            var type = window.get_window_type ();
            if (type == DESKTOP || type == DOCK || type == MENU || type == SPLASHSCREEN) {
                continue;
            }

            if (!panel.get_custom_window_rect ().overlap (window.get_frame_rect ())) {
                continue;
            }

            overlap = true;

            if (window != display.focus_window) {
                continue;
            }

            focus_overlap = true;
            focus_maximized_overlap = VERTICAL in window.get_maximized ();
        }

        update_hidden ();
    }

    private void update_hidden () {
        switch (hide_mode) {
            case MAXIMIZED_FOCUS_WINDOW:
                toggle_display (focus_maximized_overlap);
                break;

            case OVERLAPPING_FOCUS_WINDOW:
                toggle_display (focus_overlap);
                break;

            case OVERLAPPING_WINDOW:
                toggle_display (overlap);
                break;

            case ALWAYS:
                toggle_display (true);
                break;

            default:
                warning ("HideTracker: unsupported hide mode.");
                break;
        }
    }

    private void toggle_display (bool should_hide) {
#if HAS_MUTTER45
        hovered = panel.window.has_pointer ();
#else
        hovered = window_has_pointer ();
#endif

        if (should_hide && !hovered && !panel.window.has_focus ()) {
            trigger_hide ();
        } else {
            trigger_show ();
        }
    }

    private void trigger_hide () {
        // Don't hide if we have transients, e.g. an open popover, dialog, etc.
        var has_transients = false;
        panel.window.foreach_transient (() => {
            has_transients = true;
            return false;
        });

        if (has_transients) {
            reset_hide_timeout ();

            return;
        }

        hide_timeout_id = Timeout.add_once (HIDE_DELAY, () => {
            hide ();
            hide_timeout_id = 0;
        });
    }

    private void reset_hide_timeout () {
        if (hide_timeout_id != 0) {
            Source.remove (hide_timeout_id);
            hide_timeout_id = 0;
        }
    }

    private void trigger_show () {
        reset_hide_timeout ();
        show ();
    }

    private bool check_valid_gesture () {
        if (panel.anchor != BOTTOM) {
            debug ("Swipe to reveal is currently only supported for bottom anchors");
            return false;
        }

        float y;
        pan_action.get_press_coords (0, null, out y);

        var monitor_geom = display.get_monitor_geometry (panel.window.get_monitor ());
        if ((y - monitor_geom.y - monitor_geom.height).abs () < 50) { // Only start if the gesture starts near the bottom of the monitor
            return true;
        }

        return false;
    }

    private bool on_pan () {
        float delta_y;
        pan_action.get_motion_delta (0, null, out delta_y);

        if (delta_y < 0) { // Only allow swipes upwards
            panel.window.focus (pan_action.get_last_event (0).get_time ());
            trigger_show ();
        }

        return false;
    }

    private void setup_barrier () {
        var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
        var scale = display.get_monitor_scale (display.get_primary_monitor ());
        var offset = InternalUtils.scale_to_int (BARRIER_OFFSET, scale);

        switch (panel.anchor) {
            case TOP:
                setup_barrier_top (monitor_geom, offset);
                break;

            case BOTTOM:
                setup_barrier_bottom (monitor_geom, offset);
                break;

            default:
                warning ("Barrier side not supported yet");
                break;
        }
    }

#if HAS_MUTTER45
    private void setup_barrier_top (Mtk.Rectangle monitor_geom, int offset) {
#else
    private void setup_barrier_top (Meta.Rectangle monitor_geom, int offset) {
#endif
        barrier = new Barrier (
            display.get_context ().get_backend (),
            monitor_geom.x + offset,
            monitor_geom.y,
            monitor_geom.x + monitor_geom.width - offset,
            monitor_geom.y,
            POSITIVE_Y,
            0,
            0,
            int.MAX,
            int.MAX
        );

        barrier.trigger.connect (trigger_show);
    }

#if HAS_MUTTER45
    private void setup_barrier_bottom (Mtk.Rectangle monitor_geom, int offset) {
#else
    private void setup_barrier_bottom (Meta.Rectangle monitor_geom, int offset) {
#endif
        barrier = new Barrier (
            display.get_context ().get_backend (),
            monitor_geom.x + offset,
            monitor_geom.y + monitor_geom.height,
            monitor_geom.x + monitor_geom.width - offset,
            monitor_geom.y + monitor_geom.height,
            NEGATIVE_Y,
            0,
            0,
            int.MAX,
            int.MAX
        );

        barrier.trigger.connect (trigger_show);
    }
}
