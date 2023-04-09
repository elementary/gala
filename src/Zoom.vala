/*
 * Copyright 2022 elementary, Inc. (https://elementary.io)
 * Copyright 2013 Tom Beckmann
 * Copyright 2013 Rico Tzschichholz
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Zoom : Object {
    private const float MIN_ZOOM = 1.0f;
    private const float MAX_ZOOM = 10.0f;
    private const float SHORTCUT_DELTA = 0.5f;
    private const int ANIMATION_DURATION = 300;
    private const uint MOUSE_POLL_TIME = 50;

    public WindowManager wm { get; construct; }

    private uint mouse_poll_timer = 0;
    private float current_zoom = MIN_ZOOM;
    private ulong wins_handler_id = 0UL;

    private GestureTracker gesture_tracker;

    public Zoom (WindowManager wm) {
        Object (wm: wm);

        var display = wm.get_display ();
        var schema = new GLib.Settings (Config.SCHEMA + ".keybindings");

        display.add_keybinding ("zoom-in", schema, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) zoom_in);
        display.add_keybinding ("zoom-out", schema, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) zoom_out);

        gesture_tracker = new GestureTracker (ANIMATION_DURATION, ANIMATION_DURATION);
        gesture_tracker.enable_touchpad ();
        gesture_tracker.on_gesture_detected.connect (on_gesture_detected);
    }

    ~Zoom () {
        if (wm == null) {
            return;
        }

        var display = wm.get_display ();
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
        zoom (SHORTCUT_DELTA, true, wm.enable_animations);
    }

    [CCode (instance_pos = -1)]
    private void zoom_out (Meta.Display display, Meta.Window? window,
        Clutter.KeyEvent event, Meta.KeyBinding binding) {
        zoom (-SHORTCUT_DELTA, true, wm.enable_animations);
    }

    private void on_gesture_detected (Gesture gesture) {
        if (gesture.type != Gdk.EventType.TOUCHPAD_PINCH ||
            (gesture.direction != GestureDirection.IN && gesture.direction != GestureDirection.OUT)
        ) {
            return;
        }

        if ((gesture.fingers == 3 && GestureSettings.get_string ("three-finger-pinch") == "zoom") ||
            (gesture.fingers == 4 && GestureSettings.get_string ("four-finger-pinch") == "zoom")
        ) {
            zoom_with_gesture (gesture.direction);
        }
    }

    private void zoom_with_gesture (GestureDirection direction) {
        var initial_zoom = current_zoom;
        var target_zoom = (direction == GestureDirection.IN)
            ? initial_zoom - MAX_ZOOM
            : initial_zoom + MAX_ZOOM;

        GestureTracker.OnUpdate on_animation_update = (percentage) => {
            var zoom_level = GestureTracker.animation_value (initial_zoom, target_zoom, percentage);
            var delta = zoom_level - current_zoom;

            if (!wm.enable_animations) {
                if (delta.abs () >= SHORTCUT_DELTA) {
                    delta = (delta > 0) ? SHORTCUT_DELTA : -SHORTCUT_DELTA;
                } else {
                    delta = 0;
                }
            }

            zoom (delta, false, false);
        };

        gesture_tracker.connect_handlers (null, (owned) on_animation_update, null);
    }

    private void zoom (float delta, bool play_sound, bool animate) {
        // Nothing to do if zooming out of our bounds is requested
        if ((current_zoom <= MIN_ZOOM && delta < 0) || (current_zoom >= MAX_ZOOM && delta >= 0)) {
            if (play_sound) {
                Gdk.beep ();
            }
            return;
        }

        var wins = wm.ui_group;

        // Add timer to poll current mouse position to reposition window-group
        // to show requested zoomed area
        if (mouse_poll_timer == 0) {
            float mx, my;
            var client_pointer = Gdk.Display.get_default ().get_default_seat ().get_pointer ();
            client_pointer.get_position (null, out mx, out my);
            wins.set_pivot_point (mx / wins.width, my / wins.height);

            mouse_poll_timer = Timeout.add (MOUSE_POLL_TIME, () => {
                client_pointer.get_position (null, out mx, out my);
                var new_pivot = Graphene.Point ();

                new_pivot.init (mx / wins.width, my / wins.height);
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

        current_zoom += delta;
        var animation_duration = animate ? ANIMATION_DURATION : 0;

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

            wins.save_easing_state ();
            wins.set_easing_mode (Clutter.AnimationMode.EASE_OUT_CUBIC);
            wins.set_easing_duration (animation_duration);
            wins.set_scale (MIN_ZOOM, MIN_ZOOM);
            wins.restore_easing_state ();

            if (animate) {
                wins_handler_id = wins.transitions_completed.connect (() => {
                    wins.disconnect (wins_handler_id);
                    wins_handler_id = 0;
                    wins.set_pivot_point (0.0f, 0.0f);
                });
            } else {
                wins.set_pivot_point (0.0f, 0.0f);
            }

            return;
        }

        wins.save_easing_state ();
        wins.set_easing_mode (Clutter.AnimationMode.EASE_OUT_CUBIC);
        wins.set_easing_duration (animation_duration);
        wins.set_scale (current_zoom, current_zoom);
        wins.restore_easing_state ();
    }
}
