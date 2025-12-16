/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.WindowMenuManager : Object {
    public WindowManager wm { private get; construct; }
    public DaemonManager daemon_manager { private get; construct; }

    private static GLib.Settings gala_keybinding_settings = new GLib.Settings ("io.elementary.desktop.wm.keybindings");
    private static GLib.Settings keybinding_settings = new GLib.Settings ("org.gnome.desktop.wm.keybindings");

    private unowned Meta.Window? last_window = null;
    private WindowMenuItem[] last_items;

    public WindowMenuManager (WindowManager wm, DaemonManager daemon_manager) {
        Object (wm: wm, daemon_manager: daemon_manager);
    }

    construct {
        daemon_manager.window_menu_action_invoked.connect (handle_action_invoked);
    }

    public void show_window_menu (Meta.Window window, int x, int y) {
        var items = get_items_for_window (window);
        if (items.length == 0) {
            return;
        }

        DaemonWindowMenuItem[] daemon_items = {};
        for (var i = 0; i < items.length; i++) {
            daemon_items += prepare_item_for_daemon (items[i]);
        }

        daemon_manager.show_window_menu.begin (x, y, daemon_items);
    }

    private WindowMenuItem[] get_items_for_window (Meta.Window window) {
        if (ShellClientsManager.get_instance ().is_itself_positioned (window) ||
            !Utils.get_window_is_normal (window)
        ) {
            return {};
        }

        last_window = window;

        WindowMenuItem[] items = {};
        WindowMenuItem separator = { SEPARATOR, false, false, "", "", () => {} };

        WindowMenuItem screenshot_item = {
            BUTTON,
            true,
            false,
            _("Take Screenshot"),
            get_keybinding (gala_keybinding_settings, "window-screenshot"),
            (window) => wm.perform_action (Gala.ActionType.SCREENSHOT_CURRENT)
        };
        items += screenshot_item;

        items += separator;

        WindowMenuItem above_item = {
            TOGGLE,
            true,
            window.above,
            _("Always on Top"),
            get_keybinding (keybinding_settings, "always-on-top"),
            (window) => wm.perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_TOP_CURRENT)
        };
        items += above_item;

        WindowMenuItem on_all_workspaces_item = {
            TOGGLE,
            true,
            window.on_all_workspaces,
            _("Always on Visible Workspace"),
            get_keybinding (keybinding_settings, "toggle-on-all-workspaces"),
            (window) => wm.perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_VISIBLE_WORKSPACE_CURRENT)
        };
        items += on_all_workspaces_item;

        unowned var workspace = window.get_workspace ();
        var workspace_index = workspace.workspace_index;
        WindowMenuItem move_left_item = {
            BUTTON,
            workspace_index != 0,
            false,
            _("Move to Workspace Left"),
            get_keybinding (keybinding_settings, "move-to-workspace-left"),
            (window) => wm.perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_LEFT)
        };
        items += move_left_item;

        unowned var manager = window.display.get_workspace_manager ();
        WindowMenuItem move_right_item = {
            BUTTON,
            workspace_index != manager.n_workspaces - 2 || Utils.get_n_windows (workspace) != 1,
            false,
            _("Move to Workspace Right"),
            get_keybinding (keybinding_settings, "move-to-workspace-right"),
            (window) => wm.perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_RIGHT)
        };
        items += move_right_item;

        items += separator;

        WindowMenuItem move_item = {
            BUTTON,
            window.allows_move (),
            false,
            _("Move"),
            get_keybinding (keybinding_settings, "begin-move"),
            (window) => wm.perform_action (Gala.ActionType.START_MOVE_CURRENT)
        };
        items += move_item;

        WindowMenuItem resize_item = {
            BUTTON,
            window.resizeable,
            false,
            _("Resize"),
            get_keybinding (keybinding_settings, "begin-resize"),
            (window) => wm.perform_action (Gala.ActionType.START_RESIZE_CURRENT)
        };
        items += resize_item;

        var maximize_string = _("Maximize");
        if (window.maximized_horizontally) {
            maximize_string = _("Unmaximize");
        } else if (window.maximized_vertically) {
            maximize_string = _("Untile");
        }
        WindowMenuItem maximize_item = {
            BUTTON,
            window.can_maximize (),
            false,
            maximize_string,
            get_keybinding (keybinding_settings, "toggle-maximized"),
            (window) => wm.perform_action (Gala.ActionType.MAXIMIZE_CURRENT)
        };
        items += maximize_item;

        items += separator;

        WindowMenuItem hide_item = {
            BUTTON,
            window.can_minimize (),
            false,
            _("Hide"),
            get_keybinding (keybinding_settings, "minimize"),
            (window) => wm.perform_action (Gala.ActionType.HIDE_CURRENT)
        };
        items += hide_item;

        WindowMenuItem close_item = {
            BUTTON,
            window.can_close (),
            false,
            _("Close"),
            get_keybinding (keybinding_settings, "close"),
            (window) => { wm.perform_action (Gala.ActionType.CLOSE_CURRENT); }
        };
        items += close_item;

        last_items = items.copy ();

        return items;
    }

    private string get_keybinding (GLib.Settings settings, string key) {
        var strv = settings.get_strv (key);

        if (strv.length == 0) {
            return "";
        }

        return strv[0];
    }

    private DaemonWindowMenuItem prepare_item_for_daemon (WindowMenuItem item) {
        return { item.type, item.sensitive, item.toggle_state, item.display_name, item.keybinding };
    }

    private void handle_action_invoked (int action) requires (action < last_items.length) {
        last_items[action].callback (last_window);
    }
}
