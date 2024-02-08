/*
 * Copyright 2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Daemon.BackgroundMenu : Gtk.Menu {
    construct {
        var change_wallpaper = new Gtk.MenuItem.with_label (_("Change Wallpaper…"));
        change_wallpaper.activate.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://desktop/appearance/wallpaper", null);
            } catch (Error e) {
                var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    "Failed to Open Wallpaper Settings",
                    "Unable to open System Settings. A handler for the `settings://` URI scheme must be installed.",
                    "dialog-error",
                    Gtk.ButtonsType.CLOSE
                );
                message_dialog.show_error_details (e.message);
                message_dialog.run ();
                message_dialog.destroy ();
            }
        });

        var display_settings = new Gtk.MenuItem.with_label (_("Display Settings…"));
        display_settings.activate.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://display", null);
            } catch (Error e) {
                var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    "Failed to Open Display Settings",
                    "Unable to open System Settings. A handler for the `settings://` URI scheme must be installed.",
                    "dialog-warning",
                    Gtk.ButtonsType.CLOSE
                );
                message_dialog.show_error_details (e.message);
                message_dialog.run ();
                message_dialog.destroy ();
            }
        });

        var system_settings = new Gtk.MenuItem.with_label (_("System Settings…"));
        system_settings.activate.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://", null);
            } catch (Error e) {
                var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    "Failed to Open System Settings",
                    "Unable to open System Settings. A handler for the `settings://` URI scheme must be installed.",
                    "dialog-warning",
                    Gtk.ButtonsType.CLOSE
                );
                message_dialog.show_error_details (e.message);
                message_dialog.run ();
                message_dialog.destroy ();
            }
        });

        append (change_wallpaper);
        append (display_settings);
        append (new Gtk.SeparatorMenuItem ());
        append (system_settings);
        show_all ();
    }
}
