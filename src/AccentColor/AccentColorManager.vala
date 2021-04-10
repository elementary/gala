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
    private const string STYLESHEET_PREFIX = "io.elementary.stylesheet.";
    private const string TAG_ACCENT_COLOR = "Xmp.xmp.io.elementary.AccentColor";

    private Gala.AccountsService? gala_accounts_service = null;

    private Settings background_settings;
    private Settings interface_settings;

    private NamedColor[] theme_colors = {
        new NamedColor () {
            name = "Blue",
            theme = "blueberry",
            hex = "#3689e6"
        },
        new NamedColor () {
            name = "Mint",
            theme = "mint",
            hex = "#28bca3"
        },
        new NamedColor () {
            name = "Green",
            theme = "lime",
            hex = "#68b723"
        },
        new NamedColor () {
            name = "Yellow",
            theme = "banana",
            hex = "#f9c440"
        },
        new NamedColor () {
            name = "Orange",
            theme = "orange",
            hex = "#ffa154"
        },
        new NamedColor () {
            name = "Red",
            theme = "strawberry",
            hex = "#ed5353"
        },
        new NamedColor () {
            name = "Pink",
            theme = "bubblegum",
            hex = "#de3e80"
        },
        new NamedColor () {
            name = "Purple",
            theme = "grape",
            hex = "#a56de2"
        },
        new NamedColor () {
            name = "Brown",
            theme = "cocoa",
            hex = "#8a715e"
        },
        new NamedColor () {
            name = "Gray",
            theme = "slate",
            hex = "#667885"
        }
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

        background_settings.changed["picture-uri"].connect (update_accent_color);

        update_accent_color ();
    }

    private void update_accent_color () {
        bool set_accent_color_based_on_wallpaper = gala_accounts_service.prefers_accent_color == 0;

        if (set_accent_color_based_on_wallpaper) {
            var picture_uri = background_settings.get_string ("picture-uri");

            var current_stylesheet = interface_settings.get_string (STYLESHEET_KEY);
            var current_accent = current_stylesheet.replace (STYLESHEET_PREFIX, "");

            debug ("Current wallpaper: %s", picture_uri);
            debug ("Current accent color: %s", current_accent);

            NamedColor? new_color = null;
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

            debug ("New accent color: %s", new_color.theme);

            if (new_color != null && new_color.theme != current_accent) {
                interface_settings.set_string (
                    STYLESHEET_KEY,
                    STYLESHEET_PREFIX + new_color.theme
                );
            }
        }
    }

    private string? read_accent_color_name_from_exif (string picture_uri) {
        string path = "";
        GExiv2.Metadata metadata;
        try {
            path = Filename.from_uri (picture_uri);
            metadata = new GExiv2.Metadata ();
            metadata.open_path (path);
        } catch (Error e) {
            warning ("Error parsing exif metadata of \"%s\": %s", path, e.message);
            return null;
        }

        return metadata.get_tag_string (TAG_ACCENT_COLOR);
    }

    public NamedColor? get_accent_color_of_picture_simple (string picture_uri) {
        NamedColor new_color = null;

        var file = File.new_for_uri (picture_uri);

        try {
            var pixbuf = new Gdk.Pixbuf.from_file (file.get_path ());
            var color_extractor = new ColorExtractor (pixbuf);

            var palette = new Gee.ArrayList<Granite.Drawing.Color> ();
            for (int i = 0; i < theme_colors.length; i++) {
                palette.add (new Granite.Drawing.Color.from_string (theme_colors[i].hex));
            }

            var index = color_extractor.get_dominant_color_index (palette);
            new_color = theme_colors[index];
        } catch (Error e) {
            warning (e.message);
        }

        return new_color;
    }
}
