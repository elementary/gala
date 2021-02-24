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

    public const string MULTITASKING_ENABLED = "multitasking-gesture-enabled";
    public const string MULTITASKING_FINGERS = "multitasking-gesture-fingers";

    public const string WORKSPACE_ENABLED = "workspaces-gesture-enabled";
    public const string WORKSPACE_FINGERS = "workspaces-gesture-fingers";

    static construct {
        gala_settings = new GLib.Settings ("io.elementary.desktop.wm.gestures");
        touchpad_settings = new GLib.Settings ("org.gnome.desktop.peripherals.touchpad");
    }

    public bool is_natural_scroll_enabled (Gdk.InputSource device_type) {
        return (device_type == Gdk.InputSource.TOUCHSCREEN)
            ? true
            : touchpad_settings.get_boolean ("natural-scroll");
    }

    public bool is_gesture_enabled (string setting_id) {
        return gala_settings.get_boolean (setting_id);
    }

    public int gesture_fingers (string setting_id) {
        return gala_settings.get_int (setting_id);
    }
}
