/*
 * Copyright 2023-2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowSwitcherIcon : Clutter.Actor {
    private const int ICON_SIZE = 64;
    private const int WRAPPER_BORDER_RADIUS = 3;

    public Meta.Window window { get; construct; }

    private WindowIcon icon;
    private RoundedCornersEffect rounded_corners_effect;

    public bool selected {
        set {
            if (value) {
                background_color = Drawing.StyleManager.get_instance ().theme_accent_color;
            } else {
                background_color = { 0, 0, 0, 0 };
            }

            get_accessible ().notify_state_change (Atk.StateType.SELECTED, value);
            get_accessible ().notify_state_change (Atk.StateType.FOCUSED, value);
        }
    }

    public float scale_factor {
        set {
            var margin = Utils.scale_to_int (WindowSwitcher.WRAPPER_PADDING, value);
            icon.margin_top = margin;
            icon.margin_right = margin;
            icon.margin_bottom = margin;
            icon.margin_left = margin;

            rounded_corners_effect.monitor_scale = value;
        }
    }

    public WindowSwitcherIcon (Meta.Window window, float scale_factor) {
        Object (window: window);

        layout_manager = new Clutter.BinLayout ();
        reactive = true;

        icon = new WindowIcon (window, Utils.scale_to_int (ICON_SIZE, scale_factor));
        add_child (icon);

        rounded_corners_effect = new RoundedCornersEffect (WRAPPER_BORDER_RADIUS, scale_factor);
        add_effect (rounded_corners_effect);

        get_accessible ().accessible_name = window.title;
        get_accessible ().accessible_role = LIST_ITEM;
        get_accessible ().notify_state_change (Atk.StateType.FOCUSABLE, true);

        this.scale_factor = scale_factor;
    }
}
