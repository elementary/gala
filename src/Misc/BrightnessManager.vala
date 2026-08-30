/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Denis Garaev <garaevdi@outlook.com>
 */

#if HAS_MUTTER50
public struct Gala.Monitor {
    unowned Meta.Monitor meta_mointor;
    unowned Meta.Backlight backlight;
    ulong connection_id;
}

[DBus (name = "io.elementary.gala.BrightnessManager")]
public class Gala.BrightnessManager : GLib.Object {
    public signal void monitors_changed ();
    public signal void monitor_brightness_changed (uint index, uint value);

    [DBus (visible = false)]
    public unowned Meta.Display display { private get; construct; }

    private unowned Meta.MonitorManager monitor_manager;
    private GLib.List<Gala.Monitor?> monitors;

    public BrightnessManager (Meta.Display display) {
        Object (
                display: display
        );
    }

    construct {
        monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (monitors_changed_cb);
        monitors = new GLib.List<Gala.Monitor?> ();
        monitors_changed_cb ();

        var keybinding_settings = new GLib.Settings ("io.elementary.desktop.wm.keybindings");
        display.add_keybinding ("brightness-brighter", keybinding_settings, Meta.KeyBindingFlags.NONE, () => {
            try {
                set_monitor_brightness (0, get_monitor_brightness (0) + 5);
            } catch {}
        });
        display.add_keybinding ("brightness-dimmer", keybinding_settings, Meta.KeyBindingFlags.NONE, () => {
            try {
                int delta = get_monitor_brightness (0) - 5;
                if (delta < 0)
                    delta = 0;

                set_monitor_brightness (0, delta);
            } catch {}
        });
    }

    public void set_monitor_brightness (uint index, uint value) throws GLib.Error {
        if (index < monitors.length ()) {
            var backlight = monitors.nth_data (index).backlight;
            int min, max;
            backlight.get_brightness_info (out min, out max);
            backlight.set_brightness ((int) (value * (max - min) / 100) + min);
        }
    }

    public int get_monitor_brightness (uint index) throws GLib.Error {
        if (index < monitors.length ()) {
            var backlight = monitors.nth_data (index).backlight;
            int min, max;
            int value;
            backlight.get_brightness_info (out min, out max);
            value = backlight.get_brightness ();
            return (((value - min) * 100) / (max - min)).clamp (0, 100);
        } else
            return -1;
    }

    public string get_monitor_data (uint index) throws GLib.Error {
        if (index < monitors.length ())
            return monitors.nth_data (index).meta_mointor.get_display_name ();
        else
            return "";
    }

    public uint get_monitor_count () throws GLib.Error {
        return monitors.length ();
    }

    private void monitors_changed_cb () {
        foreach (var data in monitors) {
            data.backlight.disconnect (data.connection_id);
            monitors.remove (data);
        }

        var meta_monitors = monitor_manager.get_monitors ().copy ();
        foreach (var meta_monitor in meta_monitors) {
            var backlight = meta_monitor.get_backlight ();
            var connection_id = backlight.notify["brightness"].connect (monitor_brightness_changed_cb);
            if (meta_monitor.is_primary ())
                monitors.insert ({ meta_monitor, backlight, connection_id }, 0);
            else
                monitors.append ({ meta_monitor, backlight, connection_id });
        }

        monitors_changed ();
    }

    private void monitor_brightness_changed_cb (GLib.Object sender, GLib.ParamSpec prop) {
        var backlight = (Meta.Backlight) sender;
        var list = monitors.search<unowned Meta.Backlight> (backlight, (monitor, backlight) => {
            if (monitor.backlight == backlight)
                return 0;
            else
                return -1;
        }).copy ();

        if (list == null || list.is_empty ())
            return;

        var index = monitors.index (list.data);
        monitor_brightness_changed (index, get_monitor_brightness (index));
    }
}
#endif
