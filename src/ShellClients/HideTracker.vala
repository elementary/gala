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

    private static GLib.Settings behavior_settings;

    private Clutter.PanAction pan_action;

    private bool hovered = false;

    private uint num_transients = 0;
    private bool has_transients { get { return num_transients > 0; } }

    private Barrier? barrier;

    private uint hide_timeout_id = 0;

    public HideTracker (Meta.Display display, PanelWindow panel) {
        Object (display: display, panel: panel);
    }

    static construct {
        behavior_settings = new GLib.Settings ("io.elementary.desktop.wm.behavior");
    }

    construct {
        panel.window.unmanaging.connect_after (() => {
            // The timeouts hold refs on us so we stay connected to signal handlers that might
            // access the panel which was already freed. To prevent that make sure we reset
            // the timeouts so that we get freed immediately
            reset_hide_timeout ();
        });

#if HAS_MUTTER48
        unowned var cursor_tracker = display.get_compositor ().get_backend ().get_cursor_tracker ();
#else
        unowned var cursor_tracker = display.get_cursor_tracker ();
#endif
        cursor_tracker.position_invalidated.connect (() => {
            var has_pointer = panel.window.has_pointer ();

            if (hovered != has_pointer) {
                hovered = has_pointer;
                check_trigger_conditions ();
            }
        });

        display.window_created.connect (on_window_created);

        pan_action = new Clutter.PanAction () {
            n_touch_points = 1,
            pan_axis = X_AXIS
        };
        pan_action.gesture_begin.connect (check_valid_gesture);
        pan_action.pan.connect (on_pan);

#if HAS_MUTTER48
        display.get_compositor ().get_stage ().add_action_full ("panel-swipe-gesture", CAPTURE, pan_action);
#else
        display.get_stage ().add_action_full ("panel-swipe-gesture", CAPTURE, pan_action);
#endif

        panel.notify["anchor"].connect (setup_barrier);

        var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (() => {
            setup_barrier (); // Make sure barriers are still on the primary monitor
        });

        setup_barrier ();
    }

    private void on_window_created (Meta.Window new_window) {
        InternalUtils.wait_for_window_actor (new_window, (new_window_actor) => {
            if (!panel.window.is_ancestor_of_transient (new_window_actor.meta_window)) {
                return;
            }

            num_transients++;
            check_trigger_conditions ();

            new_window_actor.meta_window.unmanaged.connect (() => {
                num_transients--;
                check_trigger_conditions ();
            });
        });
    }

    private void check_trigger_conditions () {
        if (hovered || has_transients) {
            trigger_show ();
        } else {
            trigger_hide ();
        }
    }

    private void trigger_hide () {
        reset_hide_timeout ();

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
        var scale = Utils.get_ui_scaling_factor (display, display.get_primary_monitor ());
        var offset = Utils.scale_to_int (BARRIER_OFFSET, scale);

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

    private void setup_barrier_top (Mtk.Rectangle monitor_geom, int offset) {
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

        barrier.trigger.connect (on_barrier_triggered);
    }

    private void setup_barrier_bottom (Mtk.Rectangle monitor_geom, int offset) {
        barrier = new Barrier (
            display.get_context ().get_backend (),
            monitor_geom.x + offset,
            monitor_geom.y + monitor_geom.height,
            monitor_geom.x + monitor_geom.width - offset,
            monitor_geom.y + monitor_geom.height,
            NEGATIVE_Y,
            2.5,
            0,
            int.MAX,
            int.MAX
        );

        barrier.trigger.connect (on_barrier_triggered);
    }

    private void on_barrier_triggered () {
        // Showing panels in fullscreen is broken in X11
        if (InternalUtils.get_x11_in_fullscreen (display)) {
            return;
        }

        if (!display.get_monitor_in_fullscreen (panel.window.get_monitor ()) ||
            behavior_settings.get_boolean ("enable-hotcorners-in-fullscreen")
        ) {
            trigger_show ();
            // This handles the case that the user triggered the barrier but never hovered
            // the panel e.g. when triggering the barrier at a point where the dock doesnt
            // reach. In that case once the pointer is moved it'll recheck the hovered state.
            hovered = true;
        }
    }
}
