/*
 * Copyright 2022 elementary, Inc. (https://elementary.io)
 * Copyright 2013 Tom Beckmann
 * Copyright 2013 Rico Tzschichholz
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Zoom : Object, GestureTarget {
    private const float MIN_ZOOM = 1.0f;
    private const float MAX_ZOOM = 10.0f;
    private const float SHORTCUT_DELTA = 0.5f;
    private const int ANIMATION_DURATION = 300;
    private const uint MOUSE_POLL_TIME = 50;

    public WindowManager wm { get; construct; }

    public Clutter.Actor? actor { get { return wm.ui_group; } }

    private uint mouse_poll_timer = 0;
    private float current_zoom = MIN_ZOOM;
    private ulong wins_handler_id = 0UL;

    private GestureController gesture_controller;
    private double current_commit = 0;

    private GLib.Settings behavior_settings;

    public Zoom (WindowManager wm) {
        Object (wm: wm);

        unowned var display = wm.get_display ();
        var schema = new GLib.Settings ("io.elementary.desktop.wm.keybindings");

        display.add_keybinding ("zoom-in", schema, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) zoom_in);
        display.add_keybinding ("zoom-out", schema, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) zoom_out);

        gesture_controller = new GestureController (ZOOM, this) {
            snap = false
        };
        gesture_controller.enable_touchpad ();

        behavior_settings = new GLib.Settings ("io.elementary.desktop.wm.behavior");

        var scroll_action = new SuperScrollAction (display);
        scroll_action.triggered.connect (handle_super_scroll);
        display.get_stage ().add_action_full ("zoom-super-scroll-action", CAPTURE, scroll_action);
    }

    ~Zoom () {
        if (wm == null) {
            return;
        }

        unowned var display = wm.get_display ();
        display.remove_keybinding ("zoom-in");
        display.remove_keybinding ("zoom-out");

        if (mouse_poll_timer > 0) {
            Source.remove (mouse_poll_timer);
            mouse_poll_timer = 0;
        }
    }

    [CCode (instance_pos = -1)]
    private void zoom_in (Meta.Display display, Meta.Window? window,
        Clutter.KeyEvent event, Meta.KeyBinding binding) {
        zoom (SHORTCUT_DELTA, true);
    }

    [CCode (instance_pos = -1)]
    private void zoom_out (Meta.Display display, Meta.Window? window,
        Clutter.KeyEvent event, Meta.KeyBinding binding) {
        zoom (-SHORTCUT_DELTA, true);
    }

    private bool handle_super_scroll (uint32 timestamp, double dx, double dy) {
        if (behavior_settings.get_enum ("super-scroll-action") != 2) {
            return Clutter.EVENT_PROPAGATE;
        }

        var d = dx.abs () > dy.abs () ? dx : dy;

        if (d > 0) {
            zoom (SHORTCUT_DELTA, true);
        } else if (d < 0) {
            zoom (-SHORTCUT_DELTA, true);
        }

        return Clutter.EVENT_STOP;
    }

    private void zoom (float delta, bool play_sound) {
        // Nothing to do if zooming out of our bounds is requested
        if ((current_zoom <= MIN_ZOOM && delta < 0) || (current_zoom >= MAX_ZOOM && delta >= 0)) {
            if (play_sound) {
                InternalUtils.bell_notify (wm.get_display ());
            }
            return;
        }

        gesture_controller.goto (current_commit + (delta / 10));
    }

    public override void propagate (UpdateType update_type, GestureAction action, double progress) {
        switch (update_type) {
            case COMMIT:
                current_commit = progress;
                break;

            case UPDATE:
                var target_zoom = (float) progress * 10 + 1;
                if (!AnimationsSettings.get_enable_animations ()) {
                    var delta = target_zoom - current_zoom;
                    if (delta.abs () >= SHORTCUT_DELTA - float.EPSILON) {
                        target_zoom = current_zoom + ((delta > 0) ? SHORTCUT_DELTA : -SHORTCUT_DELTA);
                    } else {
                        return;
                    }
                }

                current_zoom = target_zoom;
                update_ui ();

                break;

            default:
                break;
        }
    }

    private inline Graphene.Point compute_new_pivot_point () {
        unowned var wins = wm.ui_group;
        Graphene.Point coords;
        wm.get_display ().get_cursor_tracker ().get_pointer (out coords, null);
        var new_pivot = Graphene.Point () {
            x = coords.x / wins.width,
            y = coords.y / wins.height
        };

        return new_pivot;
    }

    private void update_ui () {
        unowned var wins = wm.ui_group;
        // Add timer to poll current mouse position to reposition window-group
        // to show requested zoomed area
        if (mouse_poll_timer == 0) {
            wins.pivot_point = compute_new_pivot_point ();

            mouse_poll_timer = Timeout.add (MOUSE_POLL_TIME, () => {
                var new_pivot = compute_new_pivot_point ();
                if (wins.pivot_point.equal (new_pivot)) {
                    return true;
                }

                wins.save_easing_state ();
                wins.set_easing_mode (Clutter.AnimationMode.LINEAR);
                wins.set_easing_duration (MOUSE_POLL_TIME);
                wins.pivot_point = new_pivot;
                wins.restore_easing_state ();
                return true;
            });
        }

        if (wins_handler_id > 0) {
            wins.disconnect (wins_handler_id);
            wins_handler_id = 0;
        }

        if (current_zoom <= MIN_ZOOM) {
            current_zoom = MIN_ZOOM;

            if (mouse_poll_timer > 0) {
                Source.remove (mouse_poll_timer);
                mouse_poll_timer = 0;
            }

            wins.set_scale (MIN_ZOOM, MIN_ZOOM);
            wins.set_pivot_point (0.0f, 0.0f);

            return;
        }

        wins.set_scale (current_zoom, current_zoom);
    }
}
