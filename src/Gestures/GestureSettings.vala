/*
 * Copyright 2021 elementary, Inc (https://elementary.io)
 *           2021 José Expósito <jose.exposito89@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Utility class to access the gesture settings. Easily accessible through GestureTracker.settings.
 */
public class Gala.GestureSettings : Object {
    private static GLib.Settings gala_settings;
    private static GLib.Settings touchpad_settings;

    static construct {
        gala_settings = new GLib.Settings ("io.elementary.desktop.wm.gestures");
        touchpad_settings = new GLib.Settings ("org.gnome.desktop.peripherals.touchpad");
    }

    public bool is_natural_scroll_enabled (Clutter.InputDeviceType device_type) {
        return (device_type == Clutter.InputDeviceType.TOUCHSCREEN_DEVICE)
            ? true
            : touchpad_settings.get_boolean ("natural-scroll");
    }

    public Meta.MotionDirection? get_direction (Gesture gesture) {
        switch (gesture.direction) {
            case GestureDirection.UP:
                return Meta.MotionDirection.UP;
            case GestureDirection.DOWN:
                return Meta.MotionDirection.DOWN;
            case GestureDirection.LEFT:
                return Meta.MotionDirection.LEFT;
            case GestureDirection.RIGHT:
                return Meta.MotionDirection.RIGHT;
            default:
                return null;
        }
    }

    public Meta.MotionDirection? get_natural_scroll_direction (Gesture gesture) {
        bool natural_scroll = is_natural_scroll_enabled (gesture.performed_on_device_type);

        switch (gesture.direction) {
            case GestureDirection.UP:
                return natural_scroll ? Meta.MotionDirection.DOWN : Meta.MotionDirection.UP;
            case GestureDirection.DOWN:
                return natural_scroll ? Meta.MotionDirection.UP : Meta.MotionDirection.DOWN;
            case GestureDirection.LEFT:
                return natural_scroll ? Meta.MotionDirection.RIGHT : Meta.MotionDirection.LEFT;
            case GestureDirection.RIGHT:
                return natural_scroll ? Meta.MotionDirection.LEFT : Meta.MotionDirection.RIGHT;
            default:
                return null;
        }
    }

    public static string get_string (string setting_id) {
        return gala_settings.get_string (setting_id);
    }

    public static GestureAction get_action (Gesture gesture, out Variant? action_info = null) {
        action_info = null;
        var fingers = gesture.fingers;

        switch (gesture.type) {
            case TOUCHPAD_SWIPE:
                if (gesture.direction == LEFT || gesture.direction == RIGHT) {
                    var three_finger_swipe_horizontal = get_string ("three-finger-swipe-horizontal");
                    var four_finger_swipe_horizontal = get_string ("four-finger-swipe-horizontal");

                    if (fingers == 3 && three_finger_swipe_horizontal == "switch-to-workspace" ||
                        fingers == 4 && four_finger_swipe_horizontal == "switch-to-workspace") {
                        return SWITCH_WORKSPACE;
                    }

                    if (fingers == 3 && three_finger_swipe_horizontal == "move-to-workspace" ||
                        fingers == 4 && four_finger_swipe_horizontal == "move-to-workspace") {
                        action_info = true;
                        return SWITCH_WORKSPACE;
                    }


                    if (fingers == 3 && three_finger_swipe_horizontal == "switch-windows" ||
                        fingers == 4 && four_finger_swipe_horizontal == "switch-windows") {
                        return SWITCH_WINDOWS;
                    }
                } else if (gesture.direction == UP || gesture.direction == DOWN) {
                    var three_finger_swipe_up = get_string ("three-finger-swipe-up");
                    var four_finger_swipe_up = get_string ("four-finger-swipe-up");

                    if (fingers == 3 && three_finger_swipe_up == "multitasking-view" ||
                        fingers == 4 && four_finger_swipe_up == "multitasking-view") {
                        return MULTITASKING_VIEW;
                    }
                }
                break;

            case TOUCHPAD_PINCH:
                var three_finger_pinch = get_string ("three-finger-pinch");
                var four_finger_pinch = get_string ("four-finger-pinch");

                if (fingers == 3 && three_finger_pinch == "zoom"
                    || fingers == 4 && four_finger_pinch == "zoom"
                ) {
                    return ZOOM;
                }
                break;

            default:
                break;
        }

        return NONE;
    }
}
