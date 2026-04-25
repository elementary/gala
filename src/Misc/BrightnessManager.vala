/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Denis Garaev <garaevdi@outlook.com>
 */

#if HAS_MUTTER50
[DBus (name = "io.elementary.gala.BrightnessManager")]
public class Gala.BrightnessManager : GLib.Object {
    public int brightness {
        get {
            if (backlight == null) {
                return -1;
            }
            int min, max;
            int value;
            backlight.get_brightness_info (out min, out max);
            value = backlight.get_brightness ();
            return ((value - min) * 100) / (max - min);
        }
        set {
            if (brightness == value || backlight == null) {
                return;
            }
            int min, max;
            backlight.get_brightness_info (out min, out max);
            backlight.set_brightness ((int) (value * (max - min) / 100) + min);
        }
    }

    [DBus (visible = false)]
    public unowned Meta.Display display { private get; construct; }
    private unowned Meta.MonitorManager monitor_manager;
    private unowned Meta.Backlight? backlight;

    public BrightnessManager (Meta.Display display) {
        Object (
            display: display
        );
    }

    construct {
        monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_available_backlights);

        var keybinding_settings = new GLib.Settings ("io.elementary.desktop.wm.keybindings");
        display.add_keybinding ("brightness-brighter", keybinding_settings, Meta.KeyBindingFlags.NONE, () => {
            brightness += 5;
        });
        display.add_keybinding ("brightness-dimmer", keybinding_settings, Meta.KeyBindingFlags.NONE, () => {
            brightness -= 5;
        });

        update_available_backlights ();
    }

    private void update_available_backlights () {
        backlight = null;
        unowned var monitors = monitor_manager.get_monitors ();
        foreach (unowned var monitor in monitors) {
            if (monitor.is_primary () && monitor.is_active ()) {
                backlight = monitor.get_backlight ();
            }
        }
    }
}
#endif
