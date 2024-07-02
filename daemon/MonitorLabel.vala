/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

 public class Gala.Daemon.MonitorLabel : Gtk.Window {
    private const int SPACING = 12;
    private const string COLORED_STYLE_CSS = """
    .%s {
        background-color: alpha(%s, 0.8);
        color: %s;
    }
    """;

    public MonitorLabelInfo info { get; construct; }

    public MonitorLabel (MonitorLabelInfo info) {
        Object (info: info);
    }

    construct {
        child = new Gtk.Label (info.label);

        title = "LABEL-%i".printf (info.monitor);

        decorated = false;
        resizable = false;
        deletable = false;
        can_focus = false;
        titlebar = new Gtk.Grid ();

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_string (COLORED_STYLE_CSS.printf (title, info.background_color, info.text_color));
            get_style_context ().add_class (title);
            get_style_context ().add_class ("monitor-label");

            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            warning ("Failed to load CSS: %s", e.message);
        }

        present ();
    }
}
