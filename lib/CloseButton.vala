/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.CloseButton : Clutter.Actor {
    private const uint ANIMATION_DURATION = 100;
    private static Gee.HashMap<int, Gdk.Pixbuf?> close_pixbufs;

    public signal void triggered (uint32 timestamp);

    public float monitor_scale { get; construct set; }

    private Icon icon;
    private Clutter.ClickAction click_action;

    static construct {
        close_pixbufs = new Gee.HashMap<int, Gdk.Pixbuf?> ();
    }

    public CloseButton (float monitor_scale) {
        Object (monitor_scale: monitor_scale);
    }

    construct {
        reactive = true;

        icon = new Icon.from_resource (
            Utils.BUTTON_SIZE, monitor_scale,
            "/org/pantheon/desktop/gala/buttons/close.svg"
        ) {
            pivot_point = { 0.5f, 0.5f }
        };
        add_child (icon);

        click_action = new Clutter.ClickAction ();
        add_action (click_action);
        click_action.clicked.connect (on_clicked);
        click_action.notify["pressed"].connect (on_pressed_changed);
    }

    private void on_clicked () {
        triggered (Meta.CURRENT_TIME);
    }

    private void on_pressed_changed () {
        var estimated_duration = Utils.get_animation_duration ((uint) (ANIMATION_DURATION * (scale_x - 0.8) / 0.2));
        var scale = click_action.pressed ? 0.8 : 1.0;

        icon.save_easing_state ();
        icon.set_easing_duration (estimated_duration);
        icon.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT);
        icon.set_scale (scale, scale);
        icon.restore_easing_state ();
    }
}
