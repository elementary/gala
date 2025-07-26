/*
 * Copyright 2024-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public enum Gala.ActionType {
    NONE = 0,
    SHOW_MULTITASKING_VIEW,
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

public enum Gala.WindowMenuItemType {
    BUTTON,
    TOGGLE,
    SEPARATOR
}

public struct Gala.DaemonWindowMenuItem {
    WindowMenuItemType type;
    bool sensitive;
    bool toggle_state;
    string display_name;
    string keybinding;
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
    private const string DAEMON_DBUS_NAME = "org.pantheon.gala.daemon";
    private const string DAEMON_DBUS_OBJECT_PATH = "/org/pantheon/gala/daemon";
    private const string BG_MENU_ACTION_GROUP_PREFIX = "background-menu";
    private const string BG_MENU_ACTION_PREFIX = BG_MENU_ACTION_GROUP_PREFIX + ".";

    public signal void window_menu_action_invoked (int action);

    private Window window;
    private WindowMenu window_menu;
    private Gtk.PopoverMenu background_menu;

    private List<MonitorLabel> monitor_labels = new List<MonitorLabel> ();

    construct {
        window = new Window ();

        var background_menu_top_section = new Menu ();
        background_menu_top_section.append (
            _("Change Wallpaper…"),
            Action.print_detailed_name (BG_MENU_ACTION_PREFIX + "launch-uri", "settings://desktop/appearance/wallpaper")
        );
        background_menu_top_section.append (
            _("Display Settings…"),
            Action.print_detailed_name (BG_MENU_ACTION_PREFIX + "launch-uri", "settings://display")
        );

        var background_menu_bottom_section = new Menu ();
        background_menu_bottom_section.append (
            _("System Settings…"),
            Action.print_detailed_name (BG_MENU_ACTION_PREFIX + "launch-uri", "settings://")
        );

        var background_menu_model = new Menu ();
        background_menu_model.append_section (null, background_menu_top_section);
        background_menu_model.append_section (null, background_menu_bottom_section);

        background_menu = new Gtk.PopoverMenu.from_model (background_menu_model) {
            halign = START,
            position = BOTTOM,
            autohide = false,
            has_arrow = false
        };
        background_menu.set_parent (window.child);
        background_menu.closed.connect (window.close);

        var launch_action = new SimpleAction ("launch-uri", VariantType.STRING);
        launch_action.activate.connect (action_launch);

        var action_group = new SimpleActionGroup ();
        action_group.add_action (launch_action);

        background_menu.insert_action_group (BG_MENU_ACTION_GROUP_PREFIX, action_group);

        window_menu = new WindowMenu ();
        window_menu.set_parent (window.child);
        window_menu.closed.connect (window.close);
        window_menu.action_invoked.connect ((action) => {
            // Using Idle here because we need to wait until focus changes from the daemon window
            Idle.add (() => {
                window_menu_action_invoked (action);
                return Source.REMOVE;
            });
        });
    }

    public void show_window_menu (int display_width, int display_height, int x, int y, DaemonWindowMenuItem[] items) throws DBusError, IOError {
        window_menu.update (items);

        show_menu (window_menu, display_width, display_height, x, y);
    }

    public void show_desktop_menu (int display_width, int display_height, int x, int y) throws DBusError, IOError {
        show_menu (background_menu, display_width, display_height, x, y);
    }

    private void show_menu (Gtk.Popover menu, int display_width, int display_height, int x, int y) {
        if (!DisplayConfig.is_logical_layout ()) {
            var scale_factor = window.scale_factor;

            display_width /= scale_factor;
            display_height /= scale_factor;
            x /= scale_factor;
            y /= scale_factor;
        }

        window.child.width_request = display_width;
        window.child.height_request = display_height;
        window.present ();

        Gdk.Rectangle rect = {
            x,
            y,
            0,
            0
        };
        menu.pointing_to = rect;

        Idle.add (() => {
            menu.popup ();
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

    private static void action_launch (SimpleAction action, Variant? variant) {
        try {
            AppInfo.launch_default_for_uri (variant.get_string (), null);
        } catch (Error e) {
            var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Failed to open System Settings"),
                _("A handler for the “settings://” URI scheme must be installed."),
                "dialog-error",
                Gtk.ButtonsType.CLOSE
            );
            message_dialog.show_error_details (e.message);
            message_dialog.present ();
            message_dialog.response.connect (message_dialog.destroy);
        }
    }
}
