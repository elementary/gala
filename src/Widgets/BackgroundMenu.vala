/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.BackgroundMenu : Menu {
    public BackgroundMenu (Gala.WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        var change_wallpaper = new MenuItem (_("Change Wallpaper…"));
        change_wallpaper.activated.connect (() => {
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

        var display_settings = new MenuItem (_("Display Settings…"));
        display_settings.activated.connect (() => {
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

        var system_settings = new MenuItem (_("System Settings…"));
        system_settings.activated.connect (() => {
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

        add_menuitem (change_wallpaper);
        add_menuitem (display_settings);
        add_separator ();
        add_menuitem (system_settings);
    }
}
