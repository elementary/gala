/*
 * Copyright 2023-2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowSwitcherIcon : Clutter.Actor {
    private const int ICON_SIZE = 64;
    private const int WRAPPER_BORDER_RADIUS = 3;

    public Meta.Window window { get; construct; }
    public float monitor_scale { get; construct set; }
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

    public WindowSwitcherIcon (Meta.Window window, float monitor_scale) {
        Object (window: window, monitor_scale: monitor_scale);
    }

    construct {
        layout_manager = new Clutter.BinLayout ();
        reactive = true;

        reload_icon ();

        var rounded_corners_effect = new RoundedCornersEffect (WRAPPER_BORDER_RADIUS, monitor_scale);
        bind_property ("monitor-scale", rounded_corners_effect, "monitor-scale");
        add_effect (rounded_corners_effect);

        get_accessible ().accessible_name = window.title;
        get_accessible ().accessible_role = LIST_ITEM;
        get_accessible ().notify_state_change (Atk.StateType.FOCUSABLE, true);

        notify["monitor-scale"].connect (reload_icon);
    }

    private void reload_icon () {
        remove_all_children ();

        var margin = Utils.scale_to_int (AbstractSwitcher.WRAPPER_PADDING, monitor_scale);
        var icon = new WindowIcon (window, Utils.scale_to_int (ICON_SIZE, monitor_scale)) {
            margin_top = margin,
            margin_right = margin,
            margin_bottom = margin,
            margin_left = margin
        };
        add_child (icon);
    }
}
