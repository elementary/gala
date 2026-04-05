/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025-2026 elementary, Inc. (https://elementary.io)
 */

/*
 * Clutter.Text that automatically changes font-name to the system one and supports text shadow
 */
public class Gala.Text : Clutter.Actor {
    private static GLib.Settings gnome_interface_settings = new GLib.Settings ("org.gnome.desktop.interface");

#if HAS_MUTTER47
    public Cogl.Color color { get { return text_actor.color; } set { text_actor.color = value; } }
#else
    public Clutter.Color color { get { return text_actor.color; } set { text_actor.color = value; } }
#endif
    public Pango.EllipsizeMode ellipsize { get { return text_actor.ellipsize; } set { text_actor.ellipsize = value; } }
    public Pango.Alignment line_alignment { get { return text_actor.line_alignment; } set { text_actor.line_alignment = value; }}
    public string text { get { return text_actor.text; } set { text_actor.text = value; } }

#if HAS_MUTTER47
    public Cogl.Color shadow_color {
#else
    public Clutter.Color shadow_color {
#endif
        get { return shadow_actor.color; }
        set {
            shadow_actor.color = value;

            if (shadow_actor.color.alpha != 0 && shadow_actor.get_parent () == null) {
                insert_child_below (shadow_actor, null);
            } else if (shadow_actor.color.alpha == 0 && shadow_actor.get_parent () == this) {
                remove_child (shadow_actor);
            }
        }
    }

    public float shadow_offset_x { get { return shadow_actor.translation_x; } set { shadow_actor.translation_x = value; } }
    public float shadow_offset_y { get { return shadow_actor.translation_y; } set { shadow_actor.translation_y = value; } }
    public int shadow_blur_radius { get { return box_blur_manager.radius; } set { box_blur_manager.radius = value; } }

    private Clutter.Text text_actor;
    private Clutter.Text shadow_actor;
    private BoxBlurManager box_blur_manager;

    class construct {
        set_layout_manager_type (typeof (Clutter.BinLayout));
    }

    construct {
        text_actor = new Clutter.Text ();
        add_child (text_actor);

        shadow_actor = new Clutter.Text ();
        box_blur_manager = new BoxBlurManager (shadow_actor);

        text_actor.bind_property ("ellipsize", shadow_actor, "ellipsize");
        text_actor.bind_property ("line-alignment", shadow_actor, "line-alignment");
        text_actor.bind_property ("text", shadow_actor, "text");
        text_actor.bind_property ("font-name", shadow_actor, "font-name");

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
