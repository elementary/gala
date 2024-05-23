/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

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

    private WindowMenu? window_menu;
    private BackgroundMenu? background_menu;

    private List<MonitorLabel> monitor_labels = new List<MonitorLabel> ();

    construct {
        Bus.watch_name (BusType.SESSION, DBUS_NAME, BusNameWatcherFlags.NONE, gala_appeared, lost_gala);
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
        if (window_menu == null) {
            window_menu = new WindowMenu ();
            window_menu.perform_action.connect (perform_action);
        }

        window_menu.update (flags);

        show_menu (window_menu, display_width, display_height, x, y, true);
    }

    public void show_desktop_menu (int display_width, int display_height, int x, int y) throws DBusError, IOError {
        if (background_menu == null) {
            background_menu = new BackgroundMenu ();
        }

        show_menu (background_menu, display_width, display_height, x, y, false);
    }

    private void show_menu (Gtk.Menu menu, int display_width, int display_height, int x, int y, bool ignore_first_release) {
        var window = new Window (display_width, display_height);
        window.present ();

        menu.attach_to_widget (window.content, null);

        Gdk.Rectangle rect = {
            x,
            y,
            0,
            0
        };

        menu.show_all ();
        menu.popup_at_rect (window.get_window (), rect, NORTH, NORTH_WEST);

        menu.deactivate.connect (window.close);

        if (ignore_first_release) {
            bool first = true;
            menu.button_release_event.connect (() => {
                if (first) {
                    first = false;
                    return Gdk.EVENT_STOP;
                }

                return Gdk.EVENT_PROPAGATE;
            });
        }
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
