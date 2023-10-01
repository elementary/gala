/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.BackgroundMenu : Menu {
    public BackgroundMenu (Gala.WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        var change_wallpaper = new MenuItem.with_label (_("Change Wallpaper…"));
        change_wallpaper.activated.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://desktop/appearance/wallpaper", null);
            } catch (Error e) {
                warning ("Failed to open Wallpaper Settings: %s", e.message);
            }
        });

        var display_settings = new MenuItem.with_label (_("Display Settings…"));
        display_settings.activated.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://display", null);
            } catch (Error e) {
                warning ("Failed to open Display Settings: %s", e.message);
            }
        });

        var system_settings = new MenuItem.with_label (_("System Settings…"));
        system_settings.activated.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://", null);
            } catch (Error e) {
                warning ("Failed to open System Settings: %s", e.message);
            }
        });

        add_menuitem (change_wallpaper);
        add_menuitem (display_settings);
        add_separator ();
        add_menuitem (system_settings);
    }
}
