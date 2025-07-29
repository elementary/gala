/*
 * Copyright 2024-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public struct Gala.Daemon.DaemonWindowMenuItem {
    WindowMenuItemType type;
    bool sensitive;
    bool toggle_state;
    string display_name;
    string keybinding;
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
    private const string DAEMON_DBUS_NAME = "org.pantheon.gala.daemon";
    private const string DAEMON_DBUS_OBJECT_PATH = "/org/pantheon/gala/daemon";

    public signal void window_menu_action_invoked (int action);

    private WindowMenu? window_menu;
    private BackgroundMenu? background_menu;

    private List<MonitorLabel> monitor_labels = new List<MonitorLabel> ();

    public void show_window_menu (int display_width, int display_height, int x, int y, DaemonWindowMenuItem[] items) throws DBusError, IOError {
        if (window_menu == null) {
            window_menu = new WindowMenu ();
            window_menu.action_invoked.connect ((action) => window_menu_action_invoked (action));
        }

        window_menu.update (items);

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
            x / window.scale_factor,
            y / window.scale_factor,
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
