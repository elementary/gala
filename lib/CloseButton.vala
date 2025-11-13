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
    private bool is_pressed = false;

    static construct {
        close_pixbufs = new Gee.HashMap<int, Gdk.Pixbuf?> ();
    }

    public CloseButton (float monitor_scale) {
        Object (monitor_scale: monitor_scale);
    }

    construct {
        reactive = true;

        pixbuf_actor = new Clutter.Actor () {
            pivot_point = { 0.5f, 0.5f }
        };
        add_child (pixbuf_actor);

        load_pixbuf ();
        notify["monitor-scale"].connect (load_pixbuf);
    }

    private void load_pixbuf () {
        var pixbuf = get_close_button_pixbuf (monitor_scale);
        if (pixbuf != null) {
            var image = new Gala.Image.from_pixbuf (pixbuf);
            pixbuf_actor.set_content (image);
            pixbuf_actor.set_size (pixbuf.width, pixbuf.height);
            set_size (pixbuf.width, pixbuf.height);
        } else {
            create_error_texture ();
        }
    }

    private static Gdk.Pixbuf? get_close_button_pixbuf (float monitor_scale) {
        var height = Utils.calculate_button_size (monitor_scale);

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

    public override bool button_press_event (Clutter.Event e) {
        var estimated_duration = Utils.get_animation_duration ((uint) (ANIMATION_DURATION * (scale_x - 0.8) / 0.2));

        pixbuf_actor.save_easing_state ();
        pixbuf_actor.set_easing_duration (estimated_duration);
        pixbuf_actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT);
        pixbuf_actor.set_scale (0.8, 0.8);
        pixbuf_actor.restore_easing_state ();

        is_pressed = true;

        return Clutter.EVENT_STOP;
    }

    public override bool button_release_event (Clutter.Event e) {
        reset_scale ();

        if (is_pressed) {
            triggered (e.get_time ());
            is_pressed = false;
        }

        return Clutter.EVENT_STOP;
    }

    public override bool leave_event (Clutter.Event event) {
        reset_scale ();
        is_pressed = false;

        return Clutter.EVENT_PROPAGATE;
    }

    private void reset_scale () {
        var estimated_duration = Utils.get_animation_duration ((uint) (ANIMATION_DURATION * (1.0 - scale_x) / 0.2));

        pixbuf_actor.save_easing_state ();
        pixbuf_actor.set_easing_duration (estimated_duration);
        pixbuf_actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT);
        pixbuf_actor.set_scale (1.0, 1.0);
        pixbuf_actor.restore_easing_state ();
    }
}
