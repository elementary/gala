/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Daemon.Application : Gtk.Application {
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

        var app_provider = new Gtk.CssProvider ();
        app_provider.load_from_resource ("io/elementary/desktop/gala-daemon/gala-daemon.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), app_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    public override void activate () {
        hold ();
    }

    public override bool dbus_register (DBusConnection connection, string object_path) throws Error {
        base.dbus_register (connection, object_path);

        connection.register_object (object_path, new DBus ());

        return true;
    }
}

public static int main (string[] args) {
    GLib.Intl.setlocale (LocaleCategory.ALL, "");
    GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
    GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

    var app = new Gala.Daemon.Application ();
    return app.run ();
}
