/*
 * Copyright 2024-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[DBus (name = "org.gnome.Mutter.DisplayConfig")]
public interface Gala.Daemon.DisplayConfig : Object {
    private static bool? _is_logical_layout = null;
    private static DisplayConfig? proxy = null;

    public static bool is_logical_layout () {
        if (_is_logical_layout == null) {
            init ();
        }

        return _is_logical_layout;
    }

    private static void init () {
        try {
            proxy = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.Mutter.DisplayConfig", "/org/gnome/Mutter/DisplayConfig");
            proxy.monitors_changed.connect (update);
        } catch (Error e) {
            critical (e.message);
            _is_logical_layout = true;
            return;
        }

        update ();
    }

    private static void update () {
        uint current_serial;
        MutterReadMonitor[] mutter_monitors;
        MutterReadLogicalMonitor[] mutter_logical_monitors;
        GLib.HashTable<string, GLib.Variant> properties;
        try {
            proxy.get_current_state (out current_serial, out mutter_monitors, out mutter_logical_monitors, out properties);
        } catch (Error e) {
            critical (e.message);
            _is_logical_layout = true;
            return;
        }

        uint layout_mode = 1; // Absence of "layout-mode" means logical (= 1) according to the documentation.
        var layout_mode_variant = properties.lookup ("layout-mode");
        if (layout_mode_variant != null) {
            layout_mode = layout_mode_variant.get_uint32 ();
        }

        _is_logical_layout = layout_mode == 1;
    }

    public signal void monitors_changed ();
    public abstract void get_current_state (out uint serial, out MutterReadMonitor[] monitors, out MutterReadLogicalMonitor[] logical_monitors, out GLib.HashTable<string, GLib.Variant> properties) throws Error;
}

public struct MutterReadMonitorInfo {
    public string connector;
    public string vendor;
    public string product;
    public string serial;
    public uint hash {
        get {
            return (connector + vendor + product + serial).hash ();
        }
    }
}

public struct MutterReadMonitorMode {
    public string id;
    public int width;
    public int height;
    public double frequency;
    public double preferred_scale;
    public double[] supported_scales;
    public GLib.HashTable<string, GLib.Variant> properties;
}

public struct MutterReadMonitor {
    public MutterReadMonitorInfo monitor;
    public MutterReadMonitorMode[] modes;
    public GLib.HashTable<string, GLib.Variant> properties;
}

public struct MutterReadLogicalMonitor {
    public int x;
    public int y;
    public double scale;
    public uint transform;
    public bool primary;
    public MutterReadMonitorInfo[] monitors;
    public GLib.HashTable<string, GLib.Variant> properties;
}
