/*-
 * Copyright 2014-2021 elementary, Inc.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

 public class Gala.MonitorLabel : Hdy.Window {
    public MonitorLabelInfo info { get; construct; }

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


    public MonitorLabel (MonitorLabelInfo info) {
        Object (info: info);
    }

    construct {
        var label = new Gtk.Label (info.label) {
            margin = 12
        };

        child = label;
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
        var colored_css = COLORED_STYLE_CSS.printf (info.background_color, info.text_color);
        provider.load_from_data (colored_css, colored_css.length);

        var context = get_style_context ();
        context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        context.add_class ("colored");
        
        show_all ();
    }
}