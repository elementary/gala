/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * Implements the interface that the gnome settings daemon
 * expects from gnome shell for things like dimming on idle and
 * auto brightness.
 * See: https://gitlab.gnome.org/GNOME/gnome-shell/-/blob/main/data/dbus-interfaces/org.gnome.Shell.Brightness.xml
 */
[DBus (name = "org.gnome.Shell.Brightness")]
public class Gala.GSDBrightnessAdapter : Object {
    public signal void brightness_changed ();

    [DBus (visible = false)]
    public BrightnessManager brightness_manager { private get; construct; }

    public bool has_brightness_control { get; private set; }

    public GSDBrightnessAdapter (BrightnessManager brightness_manager) {
        Object (brightness_manager: brightness_manager);
    }

    construct {
        brightness_manager.monitors_changed.connect (on_monitors_changed);
        on_monitors_changed ();

        brightness_manager.monitor_brightness_changed.connect (on_monitor_brightness_changed);
    }

    private void on_monitors_changed () {
        try {
            has_brightness_control = brightness_manager.get_n_monitors () > 0;
        } catch (Error e) {
            warning ("Failed to query number of monitors: %s", e.message);
            has_brightness_control = false;
        }
    }

    private void on_monitor_brightness_changed () {
        brightness_changed ();
    }

    public void set_dimming (bool enable) throws DBusError, IOError {
        brightness_manager.dimming_enabled = enable;
    }

    public void set_auto_brightness_target (double target) throws DBusError, IOError {
        brightness_manager.auto_brightness_target = target;
    }
}
