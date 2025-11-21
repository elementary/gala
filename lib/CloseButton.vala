/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.CloseButton : Clutter.Actor {
    private const uint ANIMATION_DURATION = 100;
    private static Gee.HashMap<int, Gdk.Pixbuf?> close_pixbufs;

    public signal void triggered (uint32 timestamp);

    public float monitor_scale { get; construct set; }

    // used to avoid changing hitbox of the button
    private Clutter.Actor pixbuf_actor;
    private Clutter.ClickAction click_action;

    static construct {
        close_pixbufs = new Gee.HashMap<int, Gdk.Pixbuf?> ();
    }

    public CloseButton (float monitor_scale) {
        Object (monitor_scale: monitor_scale);
    }

    construct {
        reactive = true;

        pixbuf_actor = new Clutter.Actor () {
            pivot_point = { 0.5f, 0.5f },
        };
        add_child (pixbuf_actor);

        click_action = new Clutter.ClickAction ();
        add_action (click_action);
        click_action.clicked.connect (on_clicked);
        click_action.notify["pressed"].connect (on_pressed_changed);

        load_pixbuf ();
        notify["monitor-scale"].connect (load_pixbuf);
        resource_scale_changed.connect (load_pixbuf);
    }

    private void on_clicked () {
        triggered (Meta.CURRENT_TIME);
    }

    private void on_pressed_changed () {
        var estimated_duration = Utils.get_animation_duration ((uint) (ANIMATION_DURATION * (scale_x - 0.8) / 0.2));
        var scale = click_action.pressed ? 0.8 : 1.0;

        pixbuf_actor.save_easing_state ();
        pixbuf_actor.set_easing_duration (estimated_duration);
        pixbuf_actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT);
        pixbuf_actor.set_scale (scale, scale);
        pixbuf_actor.restore_easing_state ();
    }

    private void load_pixbuf () {
        var pixbuf = get_close_button_pixbuf (monitor_scale);
        if (pixbuf != null) {
            var size = Utils.calculate_button_size (monitor_scale);

            var image = new Gala.Image.from_pixbuf_with_size (size, size, pixbuf);
            pixbuf_actor.set_content (image);
            pixbuf_actor.set_size (size, size);
        } else {
            create_error_texture ();
        }
    }

    private Gdk.Pixbuf? get_close_button_pixbuf (float monitor_scale) {
        var height = (int) Math.ceilf (Utils.calculate_button_size (monitor_scale) * get_resource_scale ());

        if (close_pixbufs[height] == null) {
            try {
                close_pixbufs[height] = new Gdk.Pixbuf.from_resource_at_scale (
                    "/org/pantheon/desktop/gala/buttons/close.svg",
                    -1,
                    height,
                    true
                );
            } catch (Error e) {
                critical (e.message);
                return null;
            }
        }

        return close_pixbufs[height];
    }

    private void create_error_texture () {
        // we'll just make this red so there's at least something as an
        // indicator that loading failed. Should never happen and this
        // works as good as some weird fallback-image-failed-to-load pixbuf
        critical ("Could not create close button");

        var size = Utils.calculate_button_size (monitor_scale);
        pixbuf_actor.set_size (size, size);
        pixbuf_actor.background_color = { 255, 0, 0, 255 };
    }
}
