/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public enum Gala.ActionType {
    NONE = 0,
    SHOW_WORKSPACE_VIEW,
    MAXIMIZE_CURRENT,
    HIDE_CURRENT,
    OPEN_LAUNCHER,
    CUSTOM_COMMAND,
    WINDOW_OVERVIEW,
    WINDOW_OVERVIEW_ALL,
    SWITCH_TO_WORKSPACE_PREVIOUS,
    SWITCH_TO_WORKSPACE_NEXT,
    SWITCH_TO_WORKSPACE_LAST,
    START_MOVE_CURRENT,
    START_RESIZE_CURRENT,
    TOGGLE_ALWAYS_ON_TOP_CURRENT,
    TOGGLE_ALWAYS_ON_VISIBLE_WORKSPACE_CURRENT,
    MOVE_CURRENT_WORKSPACE_LEFT,
    MOVE_CURRENT_WORKSPACE_RIGHT,
    CLOSE_CURRENT,
    SCREENSHOT_CURRENT
}

[Flags]
public enum Gala.WindowFlags {
    NONE = 0,
    CAN_HIDE,
    CAN_MAXIMIZE,
    IS_MAXIMIZED,
    ALLOWS_MOVE,
    ALLOWS_RESIZE,
    ALWAYS_ON_TOP,
    ON_ALL_WORKSPACES,
    CAN_CLOSE,
    IS_TILED
}

[DBus (name = "org.pantheon.gala")]
public interface Gala.WMDBus : GLib.Object {
    public abstract void perform_action (Gala.ActionType type) throws DBusError, IOError;
}

public struct Gala.Daemon.MonitorLabelInfo {
    public int monitor;
    public string label;
    public string background_color;
    public string text_color;
    public int x;
    public int y;
}

[DBus (name = "org.pantheon.gala.daemon")]
public class Gala.Daemon.DBus : GLib.Object {
    private const string DBUS_NAME = "org.pantheon.gala";
    private const string DBUS_OBJECT_PATH = "/org/pantheon/gala";

    private const string DAEMON_DBUS_NAME = "org.pantheon.gala.daemon";
    private const string DAEMON_DBUS_OBJECT_PATH = "/org/pantheon/gala/daemon";

    private WMDBus? wm_proxy = null;

    private Window window;
    private WindowMenu? window_menu;

    private List<MonitorLabel> monitor_labels = new List<MonitorLabel> ();

    construct {
        Bus.watch_name (BusType.SESSION, DBUS_NAME, BusNameWatcherFlags.NONE, gala_appeared, lost_gala);

        window = new Window ();

        window_menu = new WindowMenu ();
        window_menu.set_parent (window.child);
        window_menu.closed.connect (window.close);
        window_menu.perform_action.connect ((type) => {
            Idle.add (() => {
                perform_action (type);
                return Source.REMOVE;
            });
        });
    }

    private void on_gala_get (GLib.Object? obj, GLib.AsyncResult? res) {
        try {
            wm_proxy = Bus.get_proxy.end (res);
        } catch (Error e) {
            warning ("Failed to get Gala proxy: %s", e.message);
        }
    }

    private void lost_gala () {
        wm_proxy = null;
    }

    private void gala_appeared () {
        if (wm_proxy == null) {
            Bus.get_proxy.begin<WMDBus> (BusType.SESSION, DBUS_NAME, DBUS_OBJECT_PATH, 0, null, on_gala_get);
        }
    }

    private void perform_action (Gala.ActionType type) {
        if (wm_proxy != null) {
            try {
                wm_proxy.perform_action (type);
            } catch (Error e) {
                warning ("Failed to perform Gala action over DBus: %s", e.message);
            }
        }
    }

    public void show_window_menu (Gala.WindowFlags flags, int display_width, int display_height, int x, int y) throws DBusError, IOError {
        window_menu.update (flags);

        window.default_width = display_width;
        window.default_height = display_height;
        window.present ();

        Gdk.Rectangle rect = {
            x,
            y,
            0,
            0
        };
        window_menu.pointing_to = rect;

        Idle.add (() => {
            window_menu.popup ();
            return Source.REMOVE;
        });
    }

    public void show_monitor_labels (MonitorLabelInfo[] label_infos) throws GLib.DBusError, GLib.IOError {
        hide_monitor_labels ();

        monitor_labels = new List<MonitorLabel> ();
        foreach (var info in label_infos) {
            var label = new MonitorLabel (info);
            monitor_labels.append (label);
            label.present ();
        }
    }

    public void hide_monitor_labels () throws GLib.DBusError, GLib.IOError {
        foreach (var monitor_label in monitor_labels) {
            monitor_label.close ();
        }
    }
}
