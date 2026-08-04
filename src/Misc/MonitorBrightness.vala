/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Denis Garaev <garaevdi@outlook.com>
 */

#if HAS_MUTTER50
[DBus (name = "io.elementary.gala.BrightnessManager.Monitor")]
public class Gala.MonitorBrightness : GLib.Object {
    [DBus (visible = false)]
    public unowned Meta.Monitor monitor { get; construct; }

    public int brightness {
        get {
            if (backlight == null)
                return -1;

            int min, max;
            int value;
            backlight.get_brightness_info (out min, out max);
            value = backlight.get_brightness ();
            return ((value - min) * 100) / (max - min);
        }
        set {
            if (brightness == value || backlight == null)
                return;

            int min, max;
            backlight.get_brightness_info (out min, out max);
            backlight.set_brightness ((int) (value * (max - min) / 100) + min);
        }
    }

    private unowned Meta.Backlight? backlight;

    public MonitorBrightness (Meta.Monitor monitor) {
        Object (
            monitor: monitor
        );
    }

    construct {
        backlight = monitor.get_backlight ();
    }

    [DBus (visible = false)]
    public string get_monitor_serial () {
        return monitor.get_serial ();
    }
}
#endif
