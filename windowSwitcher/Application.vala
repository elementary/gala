/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

 public class Gala.WindowSwitcher.Application : Gtk.Application {
    private WindowSwitcher window_switcher;

    public Application () {
        Object (application_id: "io.elementary.window-switcher");
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
        app_provider.load_from_resource ("/io/elementary/desktop/gala-daemon/gala-daemon.css");
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), app_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        Granite.init ();
        hold ();

        window_switcher = new WindowSwitcher ();
    }

    public override void activate () { }
}

public static int main (string[] args) {
    GLib.Intl.setlocale (LocaleCategory.ALL, "");
    GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
    GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

    var app = new Gala.WindowSwitcher.Application ();
    return app.run ();
}
