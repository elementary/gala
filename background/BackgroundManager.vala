/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

[DBus (name = "io.elementary.desktop.BackgroundManager")]
public class Gala.Background.BackgroundManager : Object {
    private static Settings gnome_settings = new Settings ("org.gnome.desktop.background");
    private static Settings elementary_settings = new Settings ("io.elementary.desktop.background");

    public signal void changed ();

    private BackgroundWindow[] windows = {};
    private Background? current_background;

    private uint idle_id = 0;

    construct {
        setup_background ();
        Gdk.Display.get_default ().get_monitors ().items_changed.connect (setup_background);

        set_background ();
        gnome_settings.changed.connect (queue_set_background);
        elementary_settings.changed.connect (queue_set_background);

        Gtk.Settings.get_default ().notify["gtk-application-prefer-dark-theme"].connect (queue_set_background);
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

    private void queue_set_background () {
        // We want to update only once for a series of changes (e.g. style to 0 and different primary color).
        if (idle_id != 0) {
            Source.remove (idle_id);
        }

        idle_id = Timeout.add (100, () => {
            set_background ();
            idle_id = 0;
            return Source.REMOVE;
        });
    }

    private void set_background () {
        var style = gnome_settings.get_enum ("picture-options");
        if (style != GDesktop.BackgroundStyle.NONE) {
            var uri = gnome_settings.get_string ("picture-uri");
            var file = File.new_for_uri (uri);
            current_background = Background.get_for_file (file);
        } else {
            Gdk.RGBA color = {};
            color.parse (gnome_settings.get_string ("primary-color"));
            current_background = Background.get_for_color (color);
        }

        if (current_background == null) {
            current_background = Background.get_for_color ({0, 0, 0, 255});
        }

        if (elementary_settings.get_boolean ("dim-wallpaper-in-dark-style")
            && Gtk.Settings.get_default ().gtk_application_prefer_dark_theme
        ) {
            current_background = Background.get_dimmed (current_background);
        }

        foreach (var window in windows) {
            window.set_background (current_background);
        }

        changed ();
    }

    public Background.ColorInformation? get_background_color_information (int height) throws DBusError, IOError {
        if (current_background == null) {
            return null;
        }

        return current_background.get_color_information (height);
    }
}
