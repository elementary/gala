/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowSwitcherIcon : RoundedCornerActor {
    private const int WRAPPER_BORDER_RADIUS = 3;

    public Meta.Window window { get; construct; }

    private WindowIcon icon;

    private bool _selected = false;
    public bool selected {
        get {
            return _selected;
        }
        set {
            _selected = value;
            if (value) {
                var rgba = InternalUtils.get_theme_accent_color ();
                background_color = {
                    (uint8) (rgba.red * 255),
                    (uint8) (rgba.green * 255),
                    (uint8) (rgba.blue * 255),
                    (uint8) (rgba.alpha * 255)
                };
            } else {
                background_color = null;
            }

            queue_redraw ();
        }
    }

    private float _scale_factor = 1.0f;
    public float scale_factor {
        get {
            return _scale_factor;
        }
        set {
            _scale_factor = value;

            update_size ();
        }
    }

    public WindowSwitcherIcon (Meta.Window window, int icon_size, float scale_factor) {
        Object (window: window);

        icon = new WindowIcon (window, InternalUtils.scale_to_int (icon_size, scale_factor));
        icon.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.BOTH, 0.5f));
        add_child (icon);

        border_radius = WRAPPER_BORDER_RADIUS;
        reactive = true;

        this.scale_factor = scale_factor;
    }

    private void update_size () {
        var indicator_size = InternalUtils.scale_to_int (
            (WindowSwitcher.ICON_SIZE + WindowSwitcher.WRAPPER_PADDING * 2),
            scale_factor
        );
        set_size (indicator_size, indicator_size);
    }
}
