/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Daemon.BackgroundMenu : Gtk.Menu {
    public const string ACTION_GROUP_PREFIX = "background-menu";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    construct {
        var change_wallpaper = new Gtk.MenuItem.with_label (_("Change Wallpaper…")) {
            action_name = ACTION_PREFIX + "launch-uri",
            action_target = new Variant.string ("settings://desktop/appearance/wallpaper")
        };

        var display_settings = new Gtk.MenuItem.with_label (_("Display Settings…")) {
            action_name = ACTION_PREFIX + "launch-uri",
            action_target = new Variant.string ("settings://display")
        };


        var system_settings = new Gtk.MenuItem.with_label (_("System Settings…")) {
            action_name = ACTION_PREFIX + "launch-uri",
            action_target = new Variant.string ("settings://")
        };

        append (change_wallpaper);
        append (display_settings);
        append (new Gtk.SeparatorMenuItem ());
        append (system_settings);
        show_all ();

        var launch_action = new SimpleAction ("launch-uri", VariantType.STRING);
        launch_action.activate.connect (action_launch);

        var action_group = new SimpleActionGroup ();
        action_group.add_action (launch_action);

        insert_action_group (ACTION_GROUP_PREFIX, action_group);
    }

    private void action_launch (SimpleAction action, Variant? variant) {
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
