/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.BlurManager : Object {
    private struct BlurData {
        ulong invalid_size_handler;
        Clutter.Actor actor;
        BackgroundBlurEffect blur_effect;
        uint x;
        uint y;
        uint width;
        uint height;
        uint clip_radius;
    }

    /**
    * Our rounded corners effect is antialiased, so we need to add a small offset to have proper corners
    */
    private const int CLIP_RADIUS_OFFSET = 2;
    private const int BLUR_RADIUS = 12;

    private static BlurManager instance;

    public static void init (WindowManagerGala wm) {
        if (instance != null) {
            return;
        }

        instance = new BlurManager (wm);
    }

    public static unowned BlurManager? get_instance () {
        return instance;
    }

    public WindowManagerGala wm { get; construct; }

    private GLib.HashTable<Meta.Window, BlurData?> blurred_windows = new GLib.HashTable<Meta.Window, BlurData?> (null, null);

    private BlurManager (WindowManagerGala wm) {
        Object (wm: wm);

        wm.get_display ().window_created.connect ((window) => {
            window.notify["mutter-hints"].connect ((obj, pspec) => parse_mutter_hints ((Meta.Window) obj));
            parse_mutter_hints (window);
        });

        unowned var monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_monitors);
    }

    /**
     * Blurs the given region of the given window.
     */
    public void set_region (Meta.Window window, uint x, uint y, uint width, uint height, uint clip_radius) {
        unowned var window_actor = (Meta.WindowActor) window.get_compositor_private ();
        if (window_actor == null) {
            warning ("Cannot blur actor: Actor is null");
            return;
        }

        var monitor_scaling_factor = wm.get_display ().get_monitor_scale (window.get_monitor ());

        var buffer_rect = window.get_buffer_rect ();
        var frame_rect = window.get_frame_rect ();
        var x_compensation = (frame_rect.x - buffer_rect.x) / monitor_scaling_factor;
        var y_compensation = (frame_rect.y - buffer_rect.y) / monitor_scaling_factor;

        var scaled_clip_radius = clip_radius;

        var blur_data = blurred_windows[window];
        if (blur_data != null) {
            blur_data.blur_effect.monitor_scale = monitor_scaling_factor;
            blur_data.actor.set_position (x + x_compensation, y + y_compensation);
            blur_data.actor.set_size (width, height);
            blur_data.x = x;
            blur_data.y = y;
            blur_data.width = width;
            blur_data.height = height;

            return;
        }

        var blur_effect = new BackgroundBlurEffect (BLUR_RADIUS, scaled_clip_radius + CLIP_RADIUS_OFFSET, monitor_scaling_factor);

        var blurred_actor = new Clutter.Actor () {
            x = x + x_compensation,
            y = y + y_compensation,
            width = width,
            height = height
        };
        blurred_actor.add_effect (blur_effect);

        window_actor.insert_child_below (blurred_actor, null);

        // When window is created its size may be 0x0, and we cannot calculate CSD decorations size.
        // To avoid that we listen to actor's width property and recalculate decorations size.
        ulong invalid_size_handler = 0;
        if (window_actor.width == 0) {
            invalid_size_handler = window_actor.notify["width"].connect (on_size_updated);
        }

        blurred_windows[window] = BlurData () {
            invalid_size_handler = invalid_size_handler,
            actor = blurred_actor,
            blur_effect = blur_effect,
            x = x,
            y = y,
            width = width,
            height = height,
            clip_radius = clip_radius
        };
    }

    public void remove_blur (Meta.Window window) {
        var blur_data = blurred_windows[window];
        if (blur_data == null) {
            return;
        }

        var actor = blur_data.actor;
        actor.remove_effect (blur_data.blur_effect);

        unowned var parent = actor.get_parent ();
        if (parent != null) {
            parent.remove_child (actor);
        }

        blurred_windows.remove (window);
    }

    private void on_size_updated (GLib.Object obj, GLib.ParamSpec pspec) {
        var window_actor = (Meta.WindowActor) obj;
        var window = window_actor.meta_window;

        var blur_data = blurred_windows[window];
        if (blur_data == null) {
            return;
        }

        window_actor.disconnect (blur_data.invalid_size_handler);
        blur_data.invalid_size_handler = 0;
        set_region (window, blur_data.x, blur_data.y, blur_data.width, blur_data.height, blur_data.clip_radius);
    }

    private void update_monitors () {
        foreach (unowned var window in blurred_windows.get_keys ()) {
            var blur_data = blurred_windows[window];

            var monitor_scaling_factor = window.display.get_monitor_scale (window.get_monitor ());
            blur_data.blur_effect.monitor_scale = monitor_scaling_factor;
        }
    }

    //X11 only
    private void parse_mutter_hints (Meta.Window window) {
        if (window.mutter_hints == null) {
            return;
        }

        var mutter_hints = window.mutter_hints.split (":");
        foreach (var mutter_hint in mutter_hints) {
            var split = mutter_hint.split ("=");

            if (split.length != 2) {
                continue;
            }

            var key = split[0];
            var val = split[1];

            switch (key) {
                case "blur":
                    var split_val = val.split (",");
                    if (split_val.length != 5) {
                        break;
                    }

                    uint parsed_x = 0, parsed_y = 0, parsed_width = 0, parsed_height = 0, parsed_clip_radius = 0;
                    if (
                        uint.try_parse (split_val[0], out parsed_x) &&
                        uint.try_parse (split_val[1], out parsed_y) &&
                        uint.try_parse (split_val[2], out parsed_width) &&
                        uint.try_parse (split_val[3], out parsed_height) &&
                        uint.try_parse (split_val[4], out parsed_clip_radius)
                    ) {
                        set_region (window, parsed_x, parsed_y, parsed_width, parsed_height, parsed_clip_radius);
                    } else {
                        warning ("Failed to parse %s as width and height", val);
                    }

                    break;
                default:
                    break;
            }
        }
    }
}
