/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

 public class Gala.Background.Application : Gtk.Application {
    private BackgroundWindow window;
    public Application () {
        Object (application_id: "io.elementary.desktop.background");
    }

    public override void startup () {
        base.startup ();

        Granite.init ();

        hold ();

        window = new BackgroundWindow ();
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
