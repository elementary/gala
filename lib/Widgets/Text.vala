/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

/*
 * Clutter.Text that automatically changes font-name to the system one
 */
public class Gala.Text : Clutter.Actor {
    private static GLib.Settings gnome_interface_settings;

#if HAS_MUTTER47
    public Cogl.Color color { get { return text_actor.color; } set { text_actor.color = value; } }
#else
    public Clutter.Color color { get { return text_actor.color; } set { text_actor.color = value; } }
#endif
    public Pango.EllipsizeMode ellipsize { get { return text_actor.ellipsize; } set { text_actor.ellipsize = value; } }
    public Pango.Alignment line_alignment {
        get { return text_actor.line_alignment; } set { text_actor.line_alignment = value; }
    }
    public string text { get { return text_actor.text; } set { text_actor.text = value; } }

    private Clutter.Text text_actor;

    static construct {
        gnome_interface_settings = new GLib.Settings ("org.gnome.desktop.interface");
    }

    class construct {
        set_layout_manager_type (typeof (Clutter.BinLayout));
    }

    construct {
        text_actor = new Clutter.Text ();
        add_child (text_actor);

        set_system_font_name ();
        gnome_interface_settings.changed["font-name"].connect (set_system_font_name);
    }

    private void set_system_font_name () {
        var name = gnome_interface_settings.get_string ("font-name").split (" ");
        var last_element_index = name.length - 1;

        if (int.try_parse (name[last_element_index])) { // if last element is a font-size
            name[last_element_index] = "12"; // hardcode size (can be changed later if needed)
        } else {
            name += "12";
        }

        text_actor.font_name = string.joinv (" ", name);
    }
}
