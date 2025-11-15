/*
 * Copyright 2021 José Expósito <jose.exposito89@gmail.com>
 * Copyright 2021-2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * Clutter actor to display text in a tooltip-like component.
 */
public class Gala.Tooltip : Clutter.Actor {
    private const int TEXT_MARGIN = 6;
    private const int CORNER_RADIUS = 3;

    public float monitor_scale { get; construct set; }

    private Gala.Text text_actor;

    public Tooltip (float monitor_scale) {
        Object (monitor_scale: monitor_scale);
    }

    construct {
        text_actor = new Gala.Text () {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            color = Drawing.Color.TOOLTIP_TEXT_COLOR
        };
        bind_property ("monitor-scale", text_actor, "margin-left", SYNC_CREATE, transform_monitor_scale_to_margin);
        bind_property ("monitor-scale", text_actor, "margin-top", SYNC_CREATE, transform_monitor_scale_to_margin);
        bind_property ("monitor-scale", text_actor, "margin-right", SYNC_CREATE, transform_monitor_scale_to_margin);
        bind_property ("monitor-scale", text_actor, "margin-bottom", SYNC_CREATE, transform_monitor_scale_to_margin);

        layout_manager = new Clutter.BinLayout ();
        background_color = Drawing.Color.TOOLTIP_BACKGROUND;
        add_child (text_actor);

        var rounded_corners_effect = new RoundedCornersEffect (CORNER_RADIUS, monitor_scale);
        bind_property ("monitor-scale", rounded_corners_effect, "monitor-scale");
        add_effect (rounded_corners_effect);
    }

    public void set_text (string new_text) {
        text_actor.text = new_text;
    }

    private static bool transform_monitor_scale_to_margin (Binding binding, Value from_value, ref Value to_value) {
        to_value.set_float (
            Utils.get_framebuffer_is_logical ()
            ? TEXT_MARGIN
            : Utils.scale_to_int (TEXT_MARGIN, from_value.get_float ())
        );
        return true;
    }
}
