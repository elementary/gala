/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Daemon.WindowMenu : Gtk.Popover {
    private static GLib.Settings gala_keybind_settings = new GLib.Settings ("org.pantheon.desktop.gala.keybindings");
    private static GLib.Settings keybind_settings = new GLib.Settings ("org.gnome.desktop.wm.keybindings");

    public signal void perform_action (Gala.ActionType type) {
        popdown ();
    }

    private Granite.AccelLabel always_on_top_accellabel;
    private Granite.AccelLabel close_accellabel;
    private Granite.AccelLabel minimize_accellabel;
    private Granite.AccelLabel move_accellabel;
    private Granite.AccelLabel move_left_accellabel;
    private Granite.AccelLabel move_right_accellabel;
    private Granite.AccelLabel on_visible_workspace_accellabel;
    private Granite.AccelLabel resize_accellabel;
    private Granite.AccelLabel screenshot_accellabel;
    private Gtk.Button minimize;
    private Gtk.Button maximize;
    private Gtk.Button move;
    private Gtk.Button resize;
    private Gtk.CheckButton always_on_top;
    private Gtk.CheckButton on_visible_workspace;
    private Gtk.Button move_left;
    private Gtk.Button move_right;
    private Gtk.Button close;
    private Gtk.Button screenshot;

    private ulong always_on_top_sid = 0U;
    private ulong on_visible_workspace_sid = 0U;

    construct {
        minimize_accellabel = new Granite.AccelLabel (_("Hide"));

        minimize = new Gtk.Button () {
            child = minimize_accellabel
        };
        minimize.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        minimize.clicked.connect (() => {
            perform_action (Gala.ActionType.HIDE_CURRENT);
        });

        maximize = new Gtk.Button ();
        maximize.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        maximize.clicked.connect (() => {
            perform_action (Gala.ActionType.MAXIMIZE_CURRENT);
        });

        move_accellabel = new Granite.AccelLabel (_("Move"));

        move = new Gtk.Button () {
            child = move_accellabel
        };
        move.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        move.clicked.connect (() => {
            perform_action (Gala.ActionType.START_MOVE_CURRENT);
        });

        resize_accellabel = new Granite.AccelLabel (_("Resize"));

        resize = new Gtk.Button () {
            child = resize_accellabel
        };
        resize.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        resize.clicked.connect (() => {
            perform_action (Gala.ActionType.START_RESIZE_CURRENT);
        });

        always_on_top_accellabel = new Granite.AccelLabel (_("Always on Top"));

        always_on_top = new Gtk.CheckButton () {
            child = always_on_top_accellabel
        };
        always_on_top.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        always_on_top_sid = always_on_top.toggled.connect (() => {
            perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_TOP_CURRENT);
        });

        on_visible_workspace_accellabel = new Granite.AccelLabel (_("Always on Visible Workspace"));

        on_visible_workspace = new Gtk.CheckButton () {
            child = on_visible_workspace_accellabel
        };
        on_visible_workspace.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        on_visible_workspace_sid = on_visible_workspace.toggled.connect (() => {
            perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_VISIBLE_WORKSPACE_CURRENT);
        });

        move_left_accellabel = new Granite.AccelLabel (_("Move to Workspace Left"));

        move_left = new Gtk.Button () {
            child = move_left_accellabel
        };
        move_left.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        move_left.clicked.connect (() => {
            perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_LEFT);
        });

        move_right_accellabel = new Granite.AccelLabel (_("Move to Workspace Right"));

        move_right = new Gtk.Button () {
            child = move_right_accellabel
        };
        move_right.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        move_right.clicked.connect (() => {
            perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_RIGHT);
        });

        screenshot_accellabel = new Granite.AccelLabel (_("Take Screenshot"));

        screenshot = new Gtk.Button () {
            child = screenshot_accellabel
        };
        screenshot.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        screenshot.clicked.connect (() => {
            perform_action (Gala.ActionType.SCREENSHOT_CURRENT);
        });

        close_accellabel = new Granite.AccelLabel (_("Close"));

        close = new Gtk.Button () {
            child = close_accellabel
        };
        close.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        close.clicked.connect (() => {
            perform_action (Gala.ActionType.CLOSE_CURRENT);
        });

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (screenshot);
        box.append (new Gtk.Separator (HORIZONTAL));
        box.append (always_on_top);
        box.append (on_visible_workspace);
        box.append (move_left);
        box.append (move_right);
        box.append (new Gtk.Separator (HORIZONTAL));
        box.append (move);
        box.append (resize);
        box.append (maximize);
        box.append (new Gtk.Separator (HORIZONTAL));
        box.append (minimize);
        box.append (close);

        child = box;
        halign = START;
        position = BOTTOM;
        autohide = false;
        has_arrow = false;
        add_css_class (Granite.STYLE_CLASS_MENU);
    }

    public void update (Gala.WindowFlags flags) {
        minimize.visible = Gala.WindowFlags.CAN_HIDE in flags;
        if (minimize.visible) {
            minimize_accellabel.accel_string = keybind_settings.get_strv ("minimize")[0];
        }

        maximize.visible = Gala.WindowFlags.CAN_MAXIMIZE in flags;
        if (maximize.visible) {
            unowned string maximize_label;
            if (Gala.WindowFlags.IS_MAXIMIZED in flags) {
                maximize_label = (Gala.WindowFlags.IS_TILED in flags) ? _("Untile") : _("Unmaximize");
            } else {
                maximize_label = _("Maximize");
            }

            maximize.get_child ().destroy ();
            maximize.child = new Granite.AccelLabel (
                maximize_label,
                keybind_settings.get_strv ("toggle-maximized")[0]
            );
        }

        move.visible = Gala.WindowFlags.ALLOWS_MOVE in flags;
        if (move.visible) {
            move_accellabel.accel_string = keybind_settings.get_strv ("begin-move")[0];
        }

        resize.visible = Gala.WindowFlags.ALLOWS_RESIZE in flags;
        if (resize.visible) {
            resize_accellabel.accel_string = keybind_settings.get_strv ("begin-resize")[0];
        }

        // Setting active causes signal fires on clicked so
        // we temporarily block those signals from emissions
        SignalHandler.block (always_on_top, always_on_top_sid);
        SignalHandler.block (on_visible_workspace, on_visible_workspace_sid);

        always_on_top.active = Gala.WindowFlags.ALWAYS_ON_TOP in flags;
        always_on_top_accellabel.accel_string = keybind_settings.get_strv ("always-on-top")[0];

        on_visible_workspace.active = Gala.WindowFlags.ON_ALL_WORKSPACES in flags;
        on_visible_workspace_accellabel.accel_string = keybind_settings.get_strv ("toggle-on-all-workspaces")[0];

        SignalHandler.unblock (always_on_top, always_on_top_sid);
        SignalHandler.unblock (on_visible_workspace, on_visible_workspace_sid);

        move_right.sensitive = !on_visible_workspace.active;
        if (move_right.sensitive) {
            move_right_accellabel.accel_string = keybind_settings.get_strv ("move-to-workspace-right")[0];
        }

        move_left.sensitive = !on_visible_workspace.active;
        if (move_left.sensitive) {
            move_left_accellabel.accel_string = keybind_settings.get_strv ("move-to-workspace-left")[0];
        }

        screenshot_accellabel.accel_string = gala_keybind_settings.get_strv ("window-screenshot")[0];

        close.visible = Gala.WindowFlags.CAN_CLOSE in flags;
        if (close.visible) {
            close_accellabel.accel_string = keybind_settings.get_strv ("close")[0];
        }
    }
}
