/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

 public class Gala.Background.Application : Gtk.Application {
    private static Settings gnome_settings = new Settings ("org.gnome.desktop.background");
    private static Settings elementary_settings = new Settings ("io.elementary.desktop.background");

    private BackgroundWindow[] windows = {};

    public Application () {
        Object (application_id: "io.elementary.desktop.background");
    }

    public override void startup () {
        base.startup ();

        hold ();

        /**
         * We have to be careful not to init Granite because Granite gets Settings sync but it takes a while
         * until the portal launches so it blocks.
         */

        setup_background ();
        Gdk.Display.get_default ().get_monitors ().items_changed.connect (setup_background);

        set_background ();
        gnome_settings.changed.connect (set_background);
    }

    private void setup_background () {
        foreach (var window in windows) {
            window.destroy ();
        }

        windows = {};

        var monitors = Gdk.Display.get_default ().get_monitors ();
        for (int i = 0; i < monitors.get_n_items (); i++) {
            windows += new BackgroundWindow (i);
        }
    }

    private void set_background () {
        var uri = gnome_settings.get_string ("picture-uri");
        var file = File.new_for_uri (uri);

        Gdk.Paintable texture;
        try {
            texture = Gdk.Texture.from_file (file);
        } catch (Error e) {
            warning ("FAILED TO LOAD TEXTURE: %s", e.message);
            return;
        }

        foreach (var window in windows) {
            window.set_background (texture);
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
