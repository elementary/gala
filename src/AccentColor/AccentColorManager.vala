/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class Gala.AccentColorManager : Object {
    private const string INTERFACE_SCHEMA = "org.gnome.desktop.interface";
    private const string STYLESHEET_KEY = "gtk-theme";
    private const string TAG_ACCENT_COLOR = "Xmp.xmp.io.elementary.AccentColor";

    private const string THEME_BLUE = "io.elementary.stylesheet.blueberry";
    private const string THEME_MINT = "io.elementary.stylesheet.mint";
    private const string THEME_GREEN = "io.elementary.stylesheet.lime";
    private const string THEME_YELLOW = "io.elementary.stylesheet.banana";
    private const string THEME_ORANGE = "io.elementary.stylesheet.orange";
    private const string THEME_RED = "io.elementary.stylesheet.strawberry";
    private const string THEME_PINK = "io.elementary.stylesheet.bubblegum";
    private const string THEME_PURPLE = "io.elementary.stylesheet.grape";
    private const string THEME_BROWN = "io.elementary.stylesheet.cocoa";
    private const string THEME_GRAY = "io.elementary.stylesheet.slate";

    private Gala.AccountsService? gala_accounts_service = null;

    private Settings background_settings;
    private Settings interface_settings;

    private NamedColor[] theme_colors = {
        new NamedColor ("Blue", THEME_BLUE),
        new NamedColor ("Mint", THEME_MINT),
        new NamedColor ("Green", THEME_GREEN),
        new NamedColor ("Yellow", THEME_YELLOW),
        new NamedColor ("Orange", THEME_ORANGE),
        new NamedColor ("Red", THEME_RED),
        new NamedColor ("Pink", THEME_PINK),
        new NamedColor ("Purple", THEME_PURPLE),
        new NamedColor ("Brown", THEME_BROWN),
        new NamedColor ("Gray", THEME_GRAY)
    };

    construct {
        background_settings = new Settings ("org.gnome.desktop.background");
        interface_settings = new Settings (INTERFACE_SCHEMA);

        string? user_path = null;
        try {
            FDO.Accounts? accounts_service = GLib.Bus.get_proxy_sync (
                GLib.BusType.SYSTEM,
               "org.freedesktop.Accounts",
               "/org/freedesktop/Accounts"
            );

            user_path = accounts_service.find_user_by_name (GLib.Environment.get_user_name ());
        } catch (Error e) {
            critical (e.message);
        }

        if (user_path != null) {
            try {
                gala_accounts_service = GLib.Bus.get_proxy_sync (
                    GLib.BusType.SYSTEM,
                    "org.freedesktop.Accounts",
                    user_path
                );

                ((DBusProxy)gala_accounts_service).g_properties_changed.connect (() => {
                    update_accent_color ();
                });
            } catch (Error e) {
                warning ("Unable to get AccountsService proxy, accent color preference may be incorrect");
            }
        }

        background_settings.changed["picture-options"].connect (update_accent_color);
        background_settings.changed["picture-uri"].connect (update_accent_color);
        background_settings.changed["primary-color"].connect (update_accent_color);

        update_accent_color ();
    }

    private void update_accent_color () {
        bool set_accent_color_auto = gala_accounts_service.prefers_accent_color == 0;

        if (!set_accent_color_auto) {
            return;
        }

        bool set_accent_color_based_on_primary_color = background_settings.get_enum ("picture-options") == 0;

        var current_stylesheet = interface_settings.get_string (STYLESHEET_KEY);

        debug ("Current stylesheet: %s", current_stylesheet);

        NamedColor? new_color = null;
        if (set_accent_color_based_on_primary_color) {
            var primary_color = background_settings.get_string ("primary-color");
            debug ("Current primary color: %s", primary_color);

            new_color = get_accent_color_based_on_primary_color (primary_color);
        } else {
            var picture_uri = background_settings.get_string ("picture-uri");
            debug ("Current wallpaper: %s", picture_uri);

            var accent_color_name = read_accent_color_name_from_exif (picture_uri);
            if (accent_color_name != null) {
                for (int i = 0; i < theme_colors.length; i++) {
                    if (theme_colors[i].name == accent_color_name) {
                        new_color = theme_colors[i];
                        break;
                    }
                }
            } else {
                new_color = get_accent_color_of_picture_simple (picture_uri);
            }
        }

        if (new_color != null && new_color.theme != current_stylesheet) {
            debug ("New stylesheet: %s", new_color.theme);

            interface_settings.set_string (
                STYLESHEET_KEY,
                new_color.theme
            );
        }
    }

    private string? read_accent_color_name_from_exif (string picture_uri) {
        string path = "";
        GExiv2.Metadata metadata;
        try {
            path = Filename.from_uri (picture_uri);
            metadata = new GExiv2.Metadata ();
            metadata.open_path (path);

            return metadata.try_get_tag_string (TAG_ACCENT_COLOR);
        } catch (Error e) {
            warning ("Error parsing exif metadata of \"%s\": %s", path, e.message);
            return null;
        }
    }

    private NamedColor? get_accent_color (ColorExtractor color_extractor) {
        var palette = new Gee.ArrayList<Drawing.Color> ();
        for (int i = 0; i < theme_colors.length; i++) {
            palette.add (theme_colors[i].color);
        }

        var index = color_extractor.get_dominant_color_index (palette);
        return theme_colors[index];
    }

    private NamedColor? get_accent_color_of_picture_simple (string picture_uri) {
        var file = File.new_for_uri (picture_uri);

        try {
            var pixbuf = new Gdk.Pixbuf.from_file (file.get_path ());
            var color_extractor = new ColorExtractor.from_pixbuf (pixbuf);

            return get_accent_color (color_extractor);
        } catch (Error e) {
            warning (e.message);
        }

        return null;
    }

    private NamedColor? get_accent_color_based_on_primary_color (string primary_color) {
        var granite_primary_color = new Drawing.Color.from_string (primary_color);
        var color_extractor = new ColorExtractor.from_primary_color (granite_primary_color);

        return get_accent_color (color_extractor);
    }
}
