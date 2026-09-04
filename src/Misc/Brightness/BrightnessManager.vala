/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

#if HAS_MUTTER50
[DBus (name = "io.elementary.gala.BrightnessManager")]
public class Gala.BrightnessManager : Object {
    /**
     * The monitors changed, you should treat everything as invalid
     * and re-query the number of monitors and their brightness.
     */
    public signal void monitors_changed ();

    /**
     * The brightness of the monitor with the given index changed.
     * Note that this might change the global brightness so it should
     * be re-queried as well.
     */
    public signal void monitor_brightness_changed (int index, double brightness);

    [DBus (visible = false)]
    public Meta.Display display { private get; construct; }

    public bool dimming_enabled { get; set; default = false; }
    public double auto_brightness_target { get; set; default = -1; }

    private Gee.ArrayList<MonitorBrightness> supported_monitors;

    [DBus (visible = false)]
    public BrightnessManager (Meta.Display display) {
        Object (display: display);
    }

    construct {
        supported_monitors = new Gee.ArrayList<MonitorBrightness> ();

        var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_monitors);
        update_monitors ();
    }

    private void update_monitors () {
        supported_monitors.clear ();

        var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        unowned var logical_monitors = monitor_manager.get_logical_monitors ();

        foreach (var logical_monitor in logical_monitors) {
            bool has_primary = false;
            bool has_backlight = false;
            foreach (var monitor in logical_monitor.get_monitors ()) {
                if (monitor.is_primary ()) {
                    has_primary = true;
                }

                if (monitor.get_backlight () != null && monitor.is_active ()) {
                    has_backlight = true;
                }
            }

            if (!has_backlight) {
                continue;
            }

            var brightness = new MonitorBrightness (logical_monitor, supported_monitors.size);
            brightness.notify["value"].connect (on_brightness_changed);

            bind_property ("dimming-enabled", brightness, "dimming-enabled", SYNC_CREATE);
            bind_property ("auto-brightness-target", brightness, "auto-brightness-target", SYNC_CREATE);

            if (has_primary) {
                supported_monitors.insert (0, brightness);
            } else {
                supported_monitors.add (brightness);
            }
        }

        monitors_changed ();
    }

    private void on_brightness_changed (Object obj, ParamSpec pspec) {
        var brightness = (MonitorBrightness) obj;
        monitor_brightness_changed (brightness.index, brightness.value);
    }

    public int get_n_monitors () throws IOError, DBusError {
        return supported_monitors.size;
    }

    public string get_monitor_name (int index) throws IOError, DBusError {
        if (index < 0 || index >= supported_monitors.size) {
            throw new IOError.INVALID_ARGUMENT ("Invalid monitor index: %d".printf (index));
        }

        return supported_monitors[index].name;
    }

    public double get_monitor_brightness (int index) throws IOError, DBusError {
        if (index < 0 || index >= supported_monitors.size) {
            throw new IOError.INVALID_ARGUMENT ("Invalid monitor index: %d".printf (index));
        }

        return supported_monitors[index].value;
    }

    public void set_monitor_brightness (int index, double brightness) throws IOError, DBusError {
        if (index < 0 || index >= supported_monitors.size) {
            throw new IOError.INVALID_ARGUMENT ("Invalid monitor index: %d".printf (index));
        }

        if (brightness < 0.0 || brightness > 1.0) {
            throw new IOError.INVALID_ARGUMENT ("Invalid brightness value: %f".printf (brightness));
        }

        supported_monitors[index].value = brightness;
    }

    /**
     * Gets the percentage that represents the "global" brightness.
     * This is currently the maximum brightness of all monitors.
     * See {@link set_global_brightness} for more information.
     */
    public double get_global_brightness () throws IOError, DBusError {
        if (supported_monitors.size == 0) {
            throw new IOError.INVALID_ARGUMENT ("No supported monitors found.");
        }

        var max = supported_monitors.max (MonitorBrightness.brightness_compare_func);
        return max.value;
    }

    /**
     * Sets a new "global" brightness.
     * This will adjust the brightness of all monitors in a way that
     * their relative brightness is kept.
     */
    public void set_global_brightness (double scale) throws IOError, DBusError {
        if (supported_monitors.size == 0) {
            throw new IOError.INVALID_ARGUMENT ("No supported monitors found.");
        }

        if (scale < 0.0 || scale > 1.0) {
            throw new IOError.INVALID_ARGUMENT ("Invalid scale value: %f".printf (scale));
        }

        var max = get_global_brightness ();

        foreach (var monitor in supported_monitors) {
            monitor.value = (monitor.value / max) * scale;
        }
    }
}
#endif
