/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Daemon.BackgroundMenu : Gtk.Popover {
    public const string ACTION_GROUP_PREFIX = "background-menu";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    public static Gtk.PopoverMenu create_popover_menu () {
        //  var change_wallpaper = new Gtk.MenuItem.with_label (_("Change Wallpaper…")) {
        //      action_name = ACTION_PREFIX + "launch-uri",
        //      action_target = new Variant.string ("settings://desktop/appearance/wallpaper")
        //  };

        //  var display_settings = new Gtk.MenuItem.with_label (_("Display Settings…")) {
        //      action_name = ACTION_PREFIX + "launch-uri",
        //      action_target = new Variant.string ("settings://display")
        //  };


        //  var system_settings = new Gtk.MenuItem.with_label (_("System Settings…")) {
        //      action_name = ACTION_PREFIX + "launch-uri",
        //      action_target = new Variant.string ("settings://")
        //  };

        //  append (change_wallpaper);
        //  append (display_settings);
        //  append (new Gtk.SeparatorMenuItem ());
        //  append (system_settings);
        //  show_all ();

        var model = new Menu ();
        model.append (_("Change Wallpaper…"), Action.print_detailed_name (ACTION_PREFIX + "launch-uri", new Variant.string ("settings://desktop/appearance/wallpaper")));

        var popover = new Gtk.PopoverMenu.from_model (model);

        var launch_action = new SimpleAction ("launch-uri", VariantType.STRING);
        launch_action.activate.connect (action_launch);

        var action_group = new SimpleActionGroup ();
        action_group.add_action (launch_action);

        popover.insert_action_group (ACTION_GROUP_PREFIX, action_group);

        return popover;
    }
}
