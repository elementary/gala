/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

 public class Gala.Daemon.MonitorLabel : Hdy.Window {
    private const int SPACING = 12;
    private const string COLORED_STYLE_CSS = """
        @define-color BG_COLOR %s;
        @define-color TEXT_COLOR %s;
        @define-color BG_COLOR_ALPHA alpha(@BG_COLOR, 0.75);
        .colored {
            background-color: @BG_COLOR_ALPHA;
            color: @TEXT_COLOR;
            text-shadow: 0 1px 1px alpha(white, 0.1);
            -gtk-icon-shadow: 0 1px 1px alpha(white, 0.1);
            -gtk-icon-palette: warning white;
        }
    """;

    public MonitorLabelInfo info { get; construct; }

    public MonitorLabel (MonitorLabelInfo info) {
        Object (info: info);
    }

    construct {
        child = new Gtk.Label (info.label) {
            margin = 12
        };

        title = "LABEL-%i".printf (info.monitor);

        input_shape_combine_region (null);
        accept_focus = false;
        decorated = false;
        resizable = false;
        deletable = false;
        can_focus = false;
        skip_taskbar_hint = true;
        skip_pager_hint = true;
        type_hint = Gdk.WindowTypeHint.TOOLTIP;
        set_keep_above (true);

        stick ();

        var scale_factor = get_style_context ().get_scale ();
        move (
            (int) (info.x / scale_factor) + SPACING,
            (int) (info.y / scale_factor) + SPACING
        );

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_data (COLORED_STYLE_CSS.printf (info.background_color, info.text_color));

            get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            get_style_context ().add_class ("colored");
        } catch (Error e) {
            warning ("Failed to load CSS: %s", e.message);
        }

        show_all ();
    }
}
