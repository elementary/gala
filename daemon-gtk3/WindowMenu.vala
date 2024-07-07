/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Daemon.WindowMenu : Gtk.Menu {
    private static GLib.Settings gala_keybind_settings = new GLib.Settings ("org.pantheon.desktop.gala.keybindings");
    private static GLib.Settings keybind_settings = new GLib.Settings ("org.gnome.desktop.wm.keybindings");

    public signal void perform_action (Gala.ActionType type);

    private Granite.AccelLabel always_on_top_accellabel;
    private Granite.AccelLabel close_accellabel;
    private Granite.AccelLabel minimize_accellabel;
    private Granite.AccelLabel move_accellabel;
    private Granite.AccelLabel move_left_accellabel;
    private Granite.AccelLabel move_right_accellabel;
    private Granite.AccelLabel on_visible_workspace_accellabel;
    private Granite.AccelLabel resize_accellabel;
    private Granite.AccelLabel screenshot_accellabel;
    private Gtk.MenuItem minimize;
    private Gtk.MenuItem maximize;
    private Gtk.MenuItem move;
    private Gtk.MenuItem resize;
    private Gtk.CheckMenuItem always_on_top;
    private Gtk.CheckMenuItem on_visible_workspace;
    private Gtk.MenuItem move_left;
    private Gtk.MenuItem move_right;
    private Gtk.MenuItem close;
    private Gtk.MenuItem screenshot;

    private ulong always_on_top_sid = 0U;
    private ulong on_visible_workspace_sid = 0U;

    construct {
        minimize_accellabel = new Granite.AccelLabel (_("Hide"));

        minimize = new Gtk.MenuItem ();
        minimize.add (minimize_accellabel);
        minimize.activate.connect (() => {
            perform_action (Gala.ActionType.HIDE_CURRENT);
        });

        maximize = new Gtk.MenuItem ();
        maximize.activate.connect (() => {
            perform_action (Gala.ActionType.MAXIMIZE_CURRENT);
        });

        move_accellabel = new Granite.AccelLabel (_("Move"));

        move = new Gtk.MenuItem ();
        move.add (move_accellabel);
        move.activate.connect (() => {
            perform_action (Gala.ActionType.START_MOVE_CURRENT);
        });

        resize_accellabel = new Granite.AccelLabel (_("Resize"));

        resize = new Gtk.MenuItem ();
        resize.add (resize_accellabel);
        resize.activate.connect (() => {
            perform_action (Gala.ActionType.START_RESIZE_CURRENT);
        });

        always_on_top_accellabel = new Granite.AccelLabel (_("Always on Top"));

        always_on_top = new Gtk.CheckMenuItem ();
        always_on_top.add (always_on_top_accellabel);
        always_on_top_sid = always_on_top.activate.connect (() => {
            perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_TOP_CURRENT);
        });

        on_visible_workspace_accellabel = new Granite.AccelLabel (_("Always on Visible Workspace"));

        on_visible_workspace = new Gtk.CheckMenuItem ();
        on_visible_workspace.add (on_visible_workspace_accellabel);
        on_visible_workspace_sid = on_visible_workspace.activate.connect (() => {
            perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_VISIBLE_WORKSPACE_CURRENT);
        });

        move_left_accellabel = new Granite.AccelLabel (_("Move to Workspace Left"));

        move_left = new Gtk.MenuItem ();
        move_left.add (move_left_accellabel);
        move_left.activate.connect (() => {
            perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_LEFT);
        });

        move_right_accellabel = new Granite.AccelLabel (_("Move to Workspace Right"));

        move_right = new Gtk.MenuItem ();
        move_right.add (move_right_accellabel);
        move_right.activate.connect (() => {
            perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_RIGHT);
        });

        screenshot_accellabel = new Granite.AccelLabel (_("Take Screenshot"));

        screenshot = new Gtk.MenuItem ();
        screenshot.add (screenshot_accellabel);
        screenshot.activate.connect (() => {
            perform_action (Gala.ActionType.SCREENSHOT_CURRENT);
        });

        close_accellabel = new Granite.AccelLabel (_("Close"));

        close = new Gtk.MenuItem ();
        close.add (close_accellabel);
        close.activate.connect (() => {
            perform_action (Gala.ActionType.CLOSE_CURRENT);
        });

        append (screenshot);
        append (new Gtk.SeparatorMenuItem ());
        append (always_on_top);
        append (on_visible_workspace);
        append (move_left);
        append (move_right);
        append (new Gtk.SeparatorMenuItem ());
        append (move);
        append (resize);
        append (maximize);
        append (new Gtk.SeparatorMenuItem ());
        append (minimize);
        append (close);
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
            maximize.add (
                new Granite.AccelLabel (
                    maximize_label,
                    keybind_settings.get_strv ("toggle-maximized")[0]
                )
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

        // Setting active causes signal fires on activate so
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
