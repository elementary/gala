/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

/* Clutter.Text with automatic management of system font */
public class Gala.Text : Clutter.Text {
    private GLib.Settings gnome_interface_settings;

    construct {
        gnome_interface_settings = new GLib.Settings ("org.gnome.desktop.interface");

        set_system_font_name ();
        gnome_interface_settings.notify["font-name"].connect (set_system_font_name);
    }

    private void set_system_font_name () {
        var name = gnome_interface_settings.get_string ("font-name").split (" ");
        var last_element_index = name.length - 1;

        if (int.try_parse (name[last_element_index])) { // if last element is a font-size
            name[last_element_index] = "12"; // hardcode size (can be changed later if needed)
        } else {
            name += "12";
        }

        font_name = string.joinv (" ", name);
    }
}
