/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

#if HAS_MUTTER50
public class Gala.MonitorBrightness : Object {
    private const string DIMMING_SCHEMA_ID = "org.gnome.settings-daemon.plugins.power";

    // This is really hacky. This causes vala to first include meta/display.h which includes
    // the file with the necessary macros that are used in meta/meta-logical-monitor.h and meta/meta-monitor.h
    // but not included there. I will upstream fixes for this but for now make it compile
    public Meta.Display display;

    public Meta.LogicalMonitor logical_monitor { private get; construct; }
    public int index { get; construct; }

    public string name { get; private set; }

    /**
     * The brightness of all physical monitors in percent (0.0 - 1.0). This might
     * sometimes not actually match the monitors actual brightness, e.g. when it gets dimmed
     * because the system is idle, or when an auto target is enabled.
     */
    public double value { get; set; default = -1; }

    public bool dimming_enabled { get; set; default = false; }
    public double auto_brightness_target { get; set; default = -1; }

    private static Settings? dimming_settings;

    private Gee.ArrayList<Meta.Backlight> backlights;
    private bool writing_backlights = false;

    public MonitorBrightness (Meta.LogicalMonitor logical_monitor, int index) {
        Object (logical_monitor: logical_monitor, index: index);
    }

    static construct {
        if (SettingsSchemaSource.get_default ().lookup (DIMMING_SCHEMA_ID, true) != null) {
            dimming_settings = new Settings (DIMMING_SCHEMA_ID);
        }
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

            if (value == -1) {
                value = get_relative_brightness (backlight);
            }

            set_relative_brightness (backlight, value);
            backlights.add (backlight);
            backlight.notify["brightness"].connect (on_brightness_changed);
        }

        notify["value"].connect (write_to_backlights);
        notify["dimming-enabled"].connect (write_to_backlights);
        notify["auto-brightness-target"].connect (write_to_backlights);
    }

    private void on_brightness_changed (Object obj, ParamSpec pspec) {
        if (writing_backlights) {
            return;
        }

        value = get_relative_brightness ((Meta.Backlight) obj);
    }

    private void write_to_backlights () {
        var real_brightness = value;
        if (auto_brightness_target >= 0) {
            /* If we have an auto brightness target we use the value as a bias around that
               instead of directly */
            real_brightness = (auto_brightness_target + value - 0.5).clamp (0.0, 1.0);
        }

        if (dimming_enabled) {
            var dimming_max = dimming_settings != null ? (double) dimming_settings.get_int ("idle-brightness") / 100.0 : 0.3;
            real_brightness = double.min (real_brightness, dimming_max);
        }

        writing_backlights = true;

        foreach (var backlight in backlights) {
            set_relative_brightness (backlight, real_brightness);
        }

        writing_backlights = false;
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
#endif
