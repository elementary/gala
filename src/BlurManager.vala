/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.BlurManager : Object {
    private struct Constraints {
        Clutter.Actor actor;
        BackgroundBlurEffect blur_effect;
        uint x;
        uint y;
        uint width;
        uint height;
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

    private GLib.HashTable<Meta.Window, Constraints?> blurred_windows = new GLib.HashTable<Meta.Window, Constraints?> (null, null);

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
        var scaled_x = Utils.scale_to_int ((int) x, monitor_scaling_factor);
        var scaled_y = Utils.scale_to_int ((int) y, monitor_scaling_factor);
        var scaled_width = Utils.scale_to_int ((int) width, monitor_scaling_factor);
        var scaled_height = Utils.scale_to_int ((int) height, monitor_scaling_factor);

        var constraints = blurred_windows[window];
        if (constraints != null) {
            constraints.blur_effect.monitor_scale = monitor_scaling_factor;
            constraints.actor.set_position (scaled_x, scaled_y);
            constraints.actor.set_size (scaled_width, scaled_height);
            constraints.x = x;
            constraints.y = y;
            constraints.width = width;
            constraints.height = height;

            return;
        }

        var blur_effect = new BackgroundBlurEffect (BLUR_RADIUS, clip_radius + CLIP_RADIUS_OFFSET, monitor_scaling_factor);

        var blurred_actor = new Clutter.Actor () {
            x = scaled_x,
            y = scaled_y,
            width = scaled_width,
            height = scaled_height
        };
        blurred_actor.add_effect (blur_effect);

        blurred_windows[window] = Constraints () {
            actor = blurred_actor,
            blur_effect = blur_effect,
            x = x,
            y = y,
            width = width,
            height = height
        };

        window_actor.insert_child_below (blurred_actor, null);

        window.unmanaging.connect ((_window) => {
            var _constraints = blurred_windows[_window];
            var _blurred_actor = _constraints.actor;
            unowned var parent = _blurred_actor.get_parent ();
            if (parent != null) {
                parent.remove_child (_blurred_actor);
            }
        });
    }

    private void update_monitors () {
        foreach (unowned var window in blurred_windows.get_keys ()) {
            var constraints = blurred_windows[window];

            var monitor_scaling_factor = wm.get_display ().get_monitor_scale (window.get_monitor ());
            var scaled_x = Utils.scale_to_int ((int) constraints.x, monitor_scaling_factor);
            var scaled_y = Utils.scale_to_int ((int) constraints.y, monitor_scaling_factor);
            var scaled_width = Utils.scale_to_int ((int) constraints.width, monitor_scaling_factor);
            var scaled_height = Utils.scale_to_int ((int) constraints.height, monitor_scaling_factor);

            constraints.actor.set_position (scaled_x, scaled_y);
            constraints.actor.set_size (scaled_width, scaled_height);
            constraints.blur_effect.monitor_scale = monitor_scaling_factor;
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
