/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WindowMenuManager : Object {
    /* This is the name of the action group the daemon uses */
    private const string ACTION_PREFIX = "window-menu.";

    private const string ACTION_SCREENSHOT = "screenshot";
    private const string ACTION_ALWAYS_ON_TOP = "always-on-top";
    private const string ACTION_ALWAYS_ON_VISIBLE_WORKSPACE = "always-on-visible-workspace";
    private const string ACTION_MOVE_LEFT = "move-left";
    private const string ACTION_MOVE_RIGHT = "move-right";
    private const string ACTION_MOVE = "move";
    private const string ACTION_RESIZE = "resize";
    private const string ACTION_MAXIMIZE = "maximize";
    private const string ACTION_HIDE = "hide";
    private const string ACTION_CLOSE = "close";

    private const ActionEntry[] ACTION_ENTRIES = {
        { ACTION_SCREENSHOT, on_screenshot },
        { ACTION_ALWAYS_ON_TOP, on_always_on_top, null, "false" },
        { ACTION_ALWAYS_ON_VISIBLE_WORKSPACE, on_always_on_visible_workspace, null, "false" },
        { ACTION_MOVE_LEFT, on_move_left },
        { ACTION_MOVE_RIGHT, on_move_right },
        { ACTION_MOVE, on_move },
        { ACTION_RESIZE, on_resize },
        { ACTION_MAXIMIZE, on_maximize },
        { ACTION_HIDE, on_hide },
        { ACTION_CLOSE, on_close }
    };

    public WindowManager wm { private get; construct; }
    public DaemonManager daemon_manager { private get; construct; }

    public SimpleActionGroup action_group { get; private set; }
    public Menu menu { get; private set; }

    private static GLib.Settings gala_keybind_settings = new GLib.Settings ("io.elementary.desktop.wm.keybindings");
    private static GLib.Settings keybind_settings = new GLib.Settings ("org.gnome.desktop.wm.keybindings");

    private Meta.Window? current_window;

    public WindowMenuManager (WindowManager wm, DaemonManager daemon_manager) {
        Object (wm: wm, daemon_manager: daemon_manager);
    }

    construct {
        action_group = new SimpleActionGroup ();
        action_group.add_action_entries (ACTION_ENTRIES, this);

        menu = new Menu ();
    }

    public void show_window_menu (Meta.Window window, int x, int y) {
        current_window = window;

        action_group.change_action_state (ACTION_ALWAYS_ON_TOP, window.above);
        action_group.change_action_state (ACTION_ALWAYS_ON_VISIBLE_WORKSPACE, window.on_all_workspaces);

        var window_ws = window.get_workspace ();
        var window_ws_index = window_ws.index ();
        var n_ws = window.display.get_workspace_manager ().n_workspaces;

        /* Always allow move left except on the first one */
        var can_move_left = window_ws_index != 0;

        /* Always allow move right except if we are the only window on
           the last not empty workspace (last one is always empty) */
        var can_move_right = !(window_ws_index == n_ws - 2 && Utils.get_n_windows (window_ws) == 1);

        ((SimpleAction) action_group.lookup_action (ACTION_MOVE_LEFT)).set_enabled (can_move_left);
        ((SimpleAction) action_group.lookup_action (ACTION_MOVE_RIGHT)).set_enabled (can_move_right);

        menu.remove_all ();

        var screenshot_item = new MenuItem (_("Take Screenshot"), ACTION_PREFIX + ACTION_SCREENSHOT);
        set_accel_attribute (screenshot_item, gala_keybind_settings, "screenshot");

        var screenshot_section = new Menu ();
        screenshot_section.append_item (screenshot_item);

        var always_on_top_item = new MenuItem (_("Always on Top"), ACTION_PREFIX + ACTION_ALWAYS_ON_TOP);
        set_accel_attribute (always_on_top_item, keybind_settings, "always-on-top");
        var always_on_visible_workspace_item = new MenuItem (_("Always on Visible Workspace"), ACTION_PREFIX + ACTION_ALWAYS_ON_VISIBLE_WORKSPACE);
        set_accel_attribute (always_on_visible_workspace_item, keybind_settings, "toggle-on-all-workspaces");
        var move_left_item = new MenuItem (_("Move to Workspace Left"), ACTION_PREFIX + ACTION_MOVE_LEFT);
        set_accel_attribute (move_left_item, keybind_settings, "move-to-workspace-left");
        var move_right_item = new MenuItem (_("Move to Workspace Right"), ACTION_PREFIX + ACTION_MOVE_RIGHT);
        set_accel_attribute (move_right_item, keybind_settings, "move-to-workspace-right");

        var workspace_section = new Menu ();
        workspace_section.append_item (always_on_top_item);
        workspace_section.append_item (always_on_visible_workspace_item);
        workspace_section.append_item (move_left_item);
        workspace_section.append_item (move_right_item);

        var move_resize_section = new Menu ();

        if (window.allows_move ()) {
            var move_item = new MenuItem (_("Move"), ACTION_PREFIX + ACTION_MOVE);
            set_accel_attribute (move_item, keybind_settings, "begin-move");
            move_resize_section.append_item (move_item);
        }

        if (window.allows_resize ()) {
            var resize_item = new MenuItem (_("Resize"), ACTION_PREFIX + ACTION_RESIZE);
            set_accel_attribute (resize_item, keybind_settings, "begin-resize");
            move_resize_section.append_item (resize_item);
        }

        if (window.can_maximize ()) {
            var maximize_label = _("Maximize");

            if (window.maximized_vertically || window.maximized_horizontally) {
                var is_tiled = window.maximized_vertically && !window.maximized_horizontally;
                maximize_label = is_tiled ? _("Untile") : _("Unmaximize");
            }

            var maximize_item = new MenuItem (maximize_label, ACTION_PREFIX + ACTION_MAXIMIZE);
            set_accel_attribute (maximize_item, keybind_settings, "toggle-maximized");
            move_resize_section.append_item (maximize_item);
        }

        var close_section = new Menu ();

        if (window.can_minimize ()) {
            var minimize_item = new MenuItem (_("Minimize"), ACTION_PREFIX + ACTION_HIDE);
            set_accel_attribute (minimize_item, keybind_settings, "minimize");
            close_section.append_item (minimize_item);
        }

        if (window.can_close ()) {
            var close_item = new MenuItem (_("Close"), ACTION_PREFIX + ACTION_CLOSE);
            set_accel_attribute (close_item, keybind_settings, "close");
            close_section.append_item (close_item);
        }

        menu.append_section (null, screenshot_section);
        menu.append_section (null, workspace_section);
        menu.append_section (null, move_resize_section);
        menu.append_section (null, close_section);

        daemon_manager.show_window_menu.begin (x, y);
    }

    private static void set_accel_attribute (MenuItem item, Settings settings, string key) {
        var accels = settings.get_strv (key);
        if (accels.length > 0) {
            item.set_attribute ("accel", "s", accels[0]);
        }
    }

    private void on_screenshot (SimpleAction action, Variant? parameters) {
        wm.perform_action (SCREENSHOT_CURRENT);
    }

    private void on_always_on_top (SimpleAction action, Variant? parameters) {
        wm.perform_action (TOGGLE_ALWAYS_ON_TOP_CURRENT);
    }

    private void on_always_on_visible_workspace (SimpleAction action, Variant? parameters) {
        wm.perform_action (TOGGLE_ALWAYS_ON_VISIBLE_WORKSPACE_CURRENT);
    }

    private void on_move_left (SimpleAction action, Variant? parameters) {
        wm.perform_action (MOVE_CURRENT_WORKSPACE_LEFT);
    }

    private void on_move_right (SimpleAction action, Variant? parameters) {
        wm.perform_action (MOVE_CURRENT_WORKSPACE_RIGHT);
    }

    private void on_move (SimpleAction action, Variant? parameters) {
        begin_grab_op (KEYBOARD_MOVING);
    }

    private void on_resize (SimpleAction action, Variant? parameters) {
        begin_grab_op (KEYBOARD_RESIZING_UNKNOWN);
    }

    private void begin_grab_op (Meta.GrabOp op) {
#if HAS_MUTTER49
        var device = Clutter.get_default_backend ().get_pointer_sprite (wm.stage);
#else
        var device = Clutter.get_default_backend ().get_default_seat ().get_pointer ();
#endif

        current_window.begin_grab_op (
            op, device,
#if !HAS_MUTTER49
            null,
#endif
            wm.get_display ().get_current_time (), null
        );
    }

    private void on_maximize (SimpleAction action, Variant? parameters) {
        wm.perform_action (MAXIMIZE_CURRENT);
    }

    private void on_hide (SimpleAction action, Variant? parameters) {
        wm.perform_action (HIDE_CURRENT);
    }

    private void on_close (SimpleAction action, Variant? parameters) {
        wm.perform_action (CLOSE_CURRENT);
    }
}
