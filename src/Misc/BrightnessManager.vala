/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Denis Garaev <garaevdi@outlook.com>
 */

#if HAS_MUTTER50
[DBus (name = "io.elementary.gala.BrightnessManager")]
public class Gala.BrightnessManager : GLib.Object {
    [DBus (visible = false)]
    public signal uint? monitor_added (MonitorBrightness monitor_brightness);
    [DBus (visible = false)]
    public signal void monitor_removed (uint connection_id);

    private int _brightness;
    public int brightness {
        get {
            if (exposed_monitors.size () == 0)
                return -1;


            return _brightness;
        }
        set {
            if (_brightness == value || exposed_monitors.size () == 0)
                return;

            foreach (var monitor_brightness in exposed_monitors.get_values ())
                monitor_brightness.brightness = value;

            _brightness = value;
        }
    }

    [DBus (visible = false)]
    public unowned Meta.Display display { private get; construct; }

    private GLib.HashTable<unowned Meta.Monitor, MonitorBrightness> exposed_monitors;
    private GLib.HashTable<unowned Meta.Monitor, uint> connection_ids;
    private unowned Meta.MonitorManager monitor_manager;

    public BrightnessManager (Meta.Display display) {
        Object (
            display: display
        );
    }

    construct {
        monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_available_backlights);
        exposed_monitors = new GLib.HashTable<unowned Meta.Monitor, MonitorBrightness> (null, null);
        connection_ids = new GLib.HashTable<unowned Meta.Monitor, uint> (null, null);

        // TODO: bind to value from gschema
        _brightness = 100;

        var keybinding_settings = new GLib.Settings ("io.elementary.desktop.wm.keybindings");
        display.add_keybinding ("brightness-brighter", keybinding_settings, Meta.KeyBindingFlags.NONE, () => {
            brightness += 5;
        });
        display.add_keybinding ("brightness-dimmer", keybinding_settings, Meta.KeyBindingFlags.NONE, () => {
            brightness -= 5;
        });
    }

    [DBus (visible = false)]
    public void update_available_backlights () {
        unowned var monitors = monitor_manager.get_monitors ();
        var new_monitors = monitors.copy ();
        var old_monitors = exposed_monitors.get_keys ();
        foreach (unowned var monitor in monitors) {
            if (monitor.get_backlight () == null)
                continue;

            if (old_monitors.find (monitor) != null) {
                old_monitors.remove (monitor);
                new_monitors.remove (monitor);
            }
        }

        if (new_monitors.length () > 0) {
            foreach (var monitor in new_monitors) {
                var monitor_brightness = new MonitorBrightness (monitor);
                var connection_id = monitor_added (monitor_brightness);
                if (connection_id != null) {
                    exposed_monitors.insert (monitor, monitor_brightness);
                    connection_ids.insert (monitor, connection_id);
                }
            }
        }

        if (old_monitors.length () > 0) {
            foreach (var monitor in old_monitors) {
                monitor_removed (connection_ids.get (monitor));
                exposed_monitors.remove (monitor);
                connection_ids.remove (monitor);
            }
        }
    }
}
#endif
