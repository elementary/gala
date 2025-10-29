/*
 * Copyright 2021 José Expósito <jose.exposito89@gmail.com>
 * Copyright 2021-2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * Clutter actor to display text in a tooltip-like component.
 */
public class Gala.Tooltip : Clutter.Actor {
    public float monitor_scale {
        set {
            rounded_corners_effect.monitor_scale = value;
        }
    }

    private Gala.Text text_actor;
    private RoundedCornersEffect rounded_corners_effect;

    construct {
        text_actor = new Gala.Text () {
            margin_left = 6,
            margin_top = 6,
            margin_bottom = 6,
            margin_right = 6,
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            color = Drawing.Color.TOOLTIP_TEXT_COLOR
        };

        add_child (text_actor);

        layout_manager = new Clutter.BinLayout ();
        background_color = Drawing.Color.TOOLTIP_BACKGROUND;

        rounded_corners_effect = new RoundedCornersEffect (3, 1.0f);
        add_effect (rounded_corners_effect);
    }

    public void set_text (string new_text) {
        text_actor.text = new_text;
    }
}
