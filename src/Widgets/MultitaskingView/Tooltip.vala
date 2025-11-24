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

    private Gala.Text text_actor;

    construct {
        text_actor = new Gala.Text () {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            color = Drawing.Color.TOOLTIP_TEXT_COLOR,
            margin_bottom = TEXT_MARGIN,
            margin_top = TEXT_MARGIN,
            margin_left = TEXT_MARGIN,
            margin_right = TEXT_MARGIN,
        };

        layout_manager = new Clutter.BinLayout ();
        background_color = Drawing.Color.TOOLTIP_BACKGROUND;
        add_child (text_actor);

        var rounded_corners_effect = new RoundedCornersEffect (CORNER_RADIUS, 1.0f);
        add_effect (rounded_corners_effect);
    }

    public void set_text (string new_text) {
        text_actor.text = new_text;
    }
}
