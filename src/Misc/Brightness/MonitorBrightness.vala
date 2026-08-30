/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.MonitorBrightness : Object {
    // This is really hacky. This causes vala to first include meta/display.h which includes
    // the file with the necessary macros that are used in meta/meta-logical-monitor.h and meta/meta-monitor.h
    // but not included there. I will upstream fixes for this but for now make it compile
    public Meta.Display display;

    public Meta.LogicalMonitor logical_monitor { private get; construct; }
    public int index { get; construct; }

    public string name { get; private set; }

    private double _value = -1;
    /**
     * The brightness of all physical monitors in percent (0.0 - 1.0). This might
     * sometimes not actually match the monitors actual brightness, e.g. when it gets dimmed
     * because the system is idle, or when an auto target is enabled.
     */
    public double value {
        get { return _value; }
        set {
            _value = value;

            writing_backlights = true;

            foreach (var backlight in backlights) {
                set_relative_brightness (backlight, value);
            }

            writing_backlights = false;
        }
    }

    private Gee.ArrayList<Meta.Backlight> backlights;
    private bool writing_backlights = false;

    public MonitorBrightness (Meta.LogicalMonitor logical_monitor, int index) {
        Object (logical_monitor: logical_monitor, index: index);
    }

    construct {
        backlights = new Gee.ArrayList<Meta.Backlight> ();

        unowned var monitors = logical_monitor.get_monitors ();

        name = monitors.first ().data.get_display_name ();

        foreach (var monitor in monitors) {
            var backlight = monitor.get_backlight ();
            if (backlight == null || !monitor.is_active ()) {
                continue;
            }

            if (_value == -1) {
                _value = get_relative_brightness (backlight);
            }

            set_relative_brightness (backlight, value);
            backlights.add (backlight);
            backlight.notify["brightness"].connect (on_brightness_changed);
        }
    }

    private void on_brightness_changed (Object obj, ParamSpec pspec) {
        if (writing_backlights) {
            return;
        }

        value = get_relative_brightness ((Meta.Backlight) obj);
    }

    private static double get_relative_brightness (Meta.Backlight backlight) {
        var current = backlight.brightness;
        var min = backlight.brightness_min;
        var max = backlight.brightness_max;

        return (double) (current - min) / (max - min);
    }

    private static void set_relative_brightness (Meta.Backlight backlight, double value) {
        var min = backlight.brightness_min;
        var max = backlight.brightness_max;

        backlight.brightness = (int) (min + (value * (max - min)));
    }

    public static int brightness_compare_func (MonitorBrightness a, MonitorBrightness b) {
        if (a.value < b.value) {
            return -1;
        } else if (a.value > b.value) {
            return 1;
        } else {
            return 0;
        }
    }
}
