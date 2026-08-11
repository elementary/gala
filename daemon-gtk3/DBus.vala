/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

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
    private Gtk.Menu? window_menu;
    private BackgroundMenu? background_menu;

    private List<MonitorLabel> monitor_labels = new List<MonitorLabel> ();

    construct {
        load_window_menu.begin ();
    }

    private async void load_window_menu () {
        DBusConnection connection;
        try {
            connection = yield Bus.get (SESSION, null);
        } catch (Error e) {
            warning ("Failed to get DBus connection: %s", e.message);
            return;
        }

        var menu_model = DBusMenuModel.get (connection, "org.pantheon.gala", "/io/elementary/gala/window_menu");
        var action_group = DBusActionGroup.get (connection, "org.pantheon.gala", "/io/elementary/gala/window_menu");

        window_menu = new Gtk.Menu.from_model (menu_model);
        window_menu.insert_action_group ("window-menu", action_group);
    }

    public void show_window_menu (int display_width, int display_height, int x, int y) throws DBusError, IOError {
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
