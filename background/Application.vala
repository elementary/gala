/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

 public class Gala.Background.Application : Gtk.Application {
    private static Settings gnome_settings = new Settings ("org.gnome.desktop.background");
    private static Settings elementary_settings = new Settings ("io.elementary.desktop.background");

    private BackgroundWindow[] windows = {};

    private uint idle_id = 0;

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
        gnome_settings.changed.connect (queue_set_background);
        elementary_settings.changed.connect (queue_set_background);
        Granite.Settings.get_default ().notify["prefers-color-scheme"].connect (queue_set_background);
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
        Gdk.Paintable paintable;

        var style = gnome_settings.get_enum ("picture-options");
        if (style != 0) {
            var uri = gnome_settings.get_string ("picture-uri");
            var file = File.new_for_uri (uri);
            try {
                paintable = Gdk.Texture.from_file (file);
            } catch (Error e) {
                warning ("Failed to load texture: %s", e.message);
                return;
            }
        } else {
            Gdk.RGBA color = {};
            color.parse (gnome_settings.get_string ("primary-color"));
            paintable = new SolidColor (color);
        }

        if (elementary_settings.get_boolean ("dim-wallpaper-in-dark-style") && Granite.Settings.get_default ().prefers_color_scheme == DARK) {
            paintable = new DimPaintable (paintable);
        }

        foreach (var window in windows) {
            window.set_background (paintable);
        }
    }

    public override void activate () { }

    private class SolidColor : Object, Gdk.Paintable {
        public Gdk.RGBA color { get; construct; }

        public SolidColor (Gdk.RGBA color) {
            Object (color: color);
        }

        public void snapshot (Gdk.Snapshot gdk_snapshot, double width, double height) {
            if (!(gdk_snapshot is Gtk.Snapshot)) {
                critical ("No Gtk Snapshot provided can't render solid color");
                return;
            }

            var snapshot = (Gtk.Snapshot) gdk_snapshot;

            var rect = Graphene.Rect ().init (0, 0, (float) width, (float) height);

            snapshot.append_color (color, rect);
        }
    }

    private class DimPaintable : Object, Gdk.Paintable {
        public Gdk.Paintable texture { get; construct; }

        public DimPaintable (Gdk.Paintable texture) {
            Object (texture: texture);
        }

        public void snapshot (Gdk.Snapshot gdk_snapshot, double width, double height) {
            if (!(gdk_snapshot is Gtk.Snapshot)) {
                critical ("No Gtk Snapshot provided can't render brightness changed");
                texture.snapshot (gdk_snapshot, width, height);
                return;
            }

            var snapshot = (Gtk.Snapshot) gdk_snapshot;

            float[] matrix_values = {
                0.55f, 0, 0, 0,
                0, 0.55f, 0, 0,
                0, 0, 0.55f, 0,
                0, 0, 0, 1,
            };

            var brightness_matrix = Graphene.Matrix ().init_from_float (matrix_values);

            snapshot.push_color_matrix (brightness_matrix, Graphene.Vec4.zero ());

            texture.snapshot (gdk_snapshot, width, height);

            snapshot.pop ();
        }
    }
}

public static int main (string[] args) {
    GLib.Intl.setlocale (LocaleCategory.ALL, "");
    GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
    GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

    var app = new Gala.Background.Application ();
    return app.run ();
}
