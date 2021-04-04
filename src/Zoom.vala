//
//  Copyright (C) 2013 Tom Beckmann, Rico Tzschichholz
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Gala {
    public class Zoom : Object {
        const float MIN_ZOOM = 1.0f;
        const float MAX_ZOOM = 10.0f;
        const float SHORTCUT_DELTA = 0.5f;
        const int ANIMATION_DURATION = 300;
        const uint MOUSE_POLL_TIME = 50;

        public WindowManager wm { get; construct; }

        uint mouse_poll_timer = 0;
        float current_zoom = MIN_ZOOM;
        ulong wins_handler_id = 0UL;

        private GestureTracker gesture_tracker;

        public Zoom (WindowManager wm) {
            Object (wm: wm);

            var display = wm.get_display ();
            var schema = new GLib.Settings (Config.SCHEMA + ".keybindings");

            display.add_keybinding ("zoom-in", schema, 0, (Meta.KeyHandlerFunc) zoom_in);
            display.add_keybinding ("zoom-out", schema, 0, (Meta.KeyHandlerFunc) zoom_out);

            gesture_tracker = new GestureTracker (ANIMATION_DURATION, ANIMATION_DURATION);
            gesture_tracker.enable_touchpad ();
            gesture_tracker.on_gesture_detected.connect (on_gesture_detected);
        }

        ~Zoom () {
            if (wm == null)
                return;

            var display = wm.get_display ();
            display.remove_keybinding ("zoom-in");
            display.remove_keybinding ("zoom-out");

            if (mouse_poll_timer > 0)
                Source.remove (mouse_poll_timer);
            mouse_poll_timer = 0;
        }

        [CCode (instance_pos = -1)]
        void zoom_in (Meta.Display display, Meta.Window? window,
            Clutter.KeyEvent event, Meta.KeyBinding binding) {
            zoom (SHORTCUT_DELTA, true, wm.enable_animations);
        }

        [CCode (instance_pos = -1)]
        void zoom_out (Meta.Display display, Meta.Window? window,
            Clutter.KeyEvent event, Meta.KeyBinding binding) {
            zoom (-SHORTCUT_DELTA, true, wm.enable_animations);
        }

        private void on_gesture_detected (Gesture gesture) {
            var enabled = gesture_tracker.settings.is_gesture_enabled (GestureSettings.ZOOM_ENABLED);
            var fingers = gesture_tracker.settings.gesture_fingers (GestureSettings.ZOOM_FINGERS);

            bool can_handle_gesture = gesture.type == Gdk.EventType.TOUCHPAD_PINCH
                && (gesture.direction == GestureDirection.IN || gesture.direction == GestureDirection.OUT)
                && gesture.fingers == fingers;

            if (enabled && can_handle_gesture) {
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

        void zoom (float delta, bool play_sound, bool animate) {
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
                    var new_pivot = new Graphene.Point ();

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

            if (current_zoom <= MIN_ZOOM) {
                current_zoom = MIN_ZOOM;

                if (mouse_poll_timer > 0)
                    Source.remove (mouse_poll_timer);
                mouse_poll_timer = 0;

                wins.save_easing_state ();
                wins.set_easing_mode (Clutter.AnimationMode.EASE_OUT_CUBIC);
                wins.set_easing_duration (animation_duration);
                wins.set_scale (MIN_ZOOM, MIN_ZOOM);
                wins.restore_easing_state ();

                if (animate) {
                    wins_handler_id = wins.transitions_completed.connect (() => {
                        wins.disconnect (wins_handler_id);
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
}
