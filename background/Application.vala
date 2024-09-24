/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Background.Application : Gtk.Application {
    private BackgroundManager background_manager;

    public Application () {
        Object (application_id: "io.elementary.desktop.background");
    }

    public override void startup () {
        base.startup ();

        hold ();

        /*
         * We have to be careful not to init Granite because Granite gets Settings sync but it takes a while
         * until the portal launches so it blocks.
         */

        background_manager = new BackgroundManager ();

        try {
            get_dbus_connection ().register_object (get_dbus_object_path (), background_manager);
        } catch (Error e) {
            warning ("Failed to export background manager: %s", e.message);
        }
    }

    public override void activate () { }
}

public static int main (string[] args) {
    GLib.Intl.setlocale (LocaleCategory.ALL, "");
    GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
    GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

    var app = new Gala.Background.Application ();
    return app.run ();
}
