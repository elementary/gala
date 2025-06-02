/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowSwitcherIcon : CanvasActor {
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
            content.invalidate ();
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

        icon = new WindowIcon (window, Utils.scale_to_int (icon_size, scale_factor));
        icon.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.BOTH, 0.5f));
        add_child (icon);

        get_accessible ().accessible_name = window.title;
        get_accessible ().accessible_role = LIST_ITEM;
        get_accessible ().notify_state_change (Atk.StateType.FOCUSABLE, true);

        reactive = true;

        this.scale_factor = scale_factor;
    }

    private void update_size () {
        var indicator_size = Utils.scale_to_int (
            (WindowSwitcher.ICON_SIZE + WindowSwitcher.WRAPPER_PADDING * 2),
            scale_factor
        );
        set_size (indicator_size, indicator_size);
    }

    protected override void draw (Cairo.Context ctx, int width, int height) {
        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();

        if (selected) {
            // draw rect
            var rgba = Drawing.StyleManager.get_instance ().theme_accent_color;
            ctx.set_source_rgba (
                rgba.red,
                rgba.green,
                rgba.blue,
                rgba.alpha
            );
            var rect_radius = Utils.scale_to_int (WRAPPER_BORDER_RADIUS, scale_factor);
            Drawing.Utilities.cairo_rounded_rectangle (ctx, 0, 0, width, height, rect_radius);
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.fill ();

            ctx.restore ();
        }

        get_accessible ().notify_state_change (Atk.StateType.SELECTED, selected);
        get_accessible ().notify_state_change (Atk.StateType.FOCUSED, selected);
    }
}
