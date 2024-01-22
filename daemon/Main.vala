//
//  Copyright (c) 2018 elementary LLC. (https://elementary.io)
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Gala {
    public class Daemon.Application : Gtk.Application {
        public Application () {
            Object (application_id: "org.pantheon.gala.daemon");
        }

        public override void startup () {
            base.startup ();

            var granite_settings = Granite.Settings.get_default ();
            var gtk_settings = Gtk.Settings.get_default ();

            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

            granite_settings.notify["prefers-color-scheme"].connect (() => {
                gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            });
        }

        public override void activate () {
            hold ();
        }

        public override bool dbus_register (DBusConnection connection, string object_path) throws Error {
            base.dbus_register (connection, object_path);

            connection.register_object (object_path, new MenuDaemon ());

            return true;
        }
    }

    public static int main (string[] args) {
        GLib.Intl.setlocale (LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

        var app = new Daemon.Application ();
        return app.run ();
    }
}
