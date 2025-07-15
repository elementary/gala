/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowSwitcherIcon : Clutter.Actor {
    private const int WRAPPER_BORDER_RADIUS = 3;

    public Meta.Window window { get; construct; }

    private WindowIcon icon;
    private RoundedCornersEffect rounded_corners_effect;

    public bool selected {
        set {
            if (value) {
                var accent_color = Drawing.StyleManager.get_instance ().theme_accent_color;
                background_color = {
                    (uint8) (accent_color.red * uint8.MAX),
                    (uint8) (accent_color.green * uint8.MAX),
                    (uint8) (accent_color.blue * uint8.MAX),
                    (uint8) (accent_color.alpha * uint8.MAX)
                };
            } else {
#if HAS_MUTTER47
                background_color = Cogl.Color.from_4f (0, 0, 0, 0);
#else
                background_color = Clutter.Color.alloc ();
#endif
            }

            get_accessible ().notify_state_change (Atk.StateType.SELECTED, value);
            get_accessible ().notify_state_change (Atk.StateType.FOCUSED, value);
        }
    }

    public float scale_factor {
        set {
            var indicator_size = Utils.scale_to_int (
                (WindowSwitcher.ICON_SIZE + WindowSwitcher.WRAPPER_PADDING * 2),
                value
            );
            set_size (indicator_size, indicator_size);

            rounded_corners_effect.monitor_scale = value;
        }
    }

    public WindowSwitcherIcon (Meta.Window window, int icon_size, float scale_factor) {
        Object (window: window);

        icon = new WindowIcon (window, Utils.scale_to_int (icon_size, scale_factor));
        icon.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.BOTH, 0.5f));
        add_child (icon);

        rounded_corners_effect = new RoundedCornersEffect (WRAPPER_BORDER_RADIUS, scale_factor);
        add_effect (rounded_corners_effect);

        get_accessible ().accessible_name = window.title;
        get_accessible ().accessible_role = LIST_ITEM;
        get_accessible ().notify_state_change (Atk.StateType.FOCUSABLE, true);

        reactive = true;

        this.scale_factor = scale_factor;
    }
}
