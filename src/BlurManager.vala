/*
* SPDX-License-Identifier: GPL-3.0-or-later
* SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.BlurManager : Object {
    private struct BlurData {
        BackgroundBlurEffect blur_effect;
        uint left;
        uint right;
        uint top;
        uint bottom;
        uint clip_radius;
    }

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
    }

    construct {
        wm.get_display ().window_created.connect ((window) => {
            window.notify["mutter-hints"].connect ((obj, pspec) => parse_mutter_hints ((Meta.Window) obj));
            parse_mutter_hints (window);
        });

        unowned var monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (() => {
            foreach (unowned var window in blurred_windows.get_keys ()) {
                blurred_windows[window].blur_effect.monitor_scale = window.display.get_monitor_scale (window.get_monitor ());
            }
        });
    }

    /**
     * Blurs the given region of the given window.
     */
    public void add_blur (Meta.Window window, uint left, uint right, uint top, uint bottom, uint clip_radius) {
        unowned var window_actor = (Meta.WindowActor) window.get_compositor_private ();
        if (window_actor == null) {
            critical ("Cannot blur actor: Actor is null");
            return;
        }

        var blur_data = blurred_windows[window];
        if (blur_data == null) {
            var blur_effect = new BackgroundBlurEffect (
                BLUR_RADIUS,
                (int) clip_radius,
                window.display.get_monitor_scale (window.get_monitor ())
            );

            window_actor.add_effect (blur_effect);

            blur_data = { blur_effect, left, right, top, bottom, clip_radius };
            blurred_windows[window] = blur_data;

            // TODO: We can require users of blur API to calculate shadow_size themselves and remove connecting to this
            window.size_changed.connect (on_size_changed);
        }

        var buffer_rect = window.get_buffer_rect ();
        var frame_rect = window.get_frame_rect ();
        var left_shadow_size = frame_rect.x - buffer_rect.x;
        var right_shadow_size = buffer_rect.width - frame_rect.width - left_shadow_size;
        var top_shadow_size = frame_rect.y - buffer_rect.y;
        var bottom_shadow_size = buffer_rect.height - frame_rect.height - top_shadow_size;

        blur_data.blur_effect.left = left_shadow_size + left;
        blur_data.blur_effect.right = right_shadow_size + right;
        blur_data.blur_effect.top = top_shadow_size + top;
        blur_data.blur_effect.bottom = bottom_shadow_size + bottom;
    }

    public void remove_blur (Meta.Window window) {
        unowned var window_actor = (Meta.WindowActor) window.get_compositor_private ();
        var blur_data = blurred_windows.take (window);

        if (blur_data == null || window_actor == null) {
            return;
        }

        window_actor.remove_effect (blur_data.blur_effect);
    }

    private void on_size_changed (Meta.Window window) {
        var blur_data = blurred_windows[window];
        if (blur_data == null) {
            return;
        }

        add_blur (window, blur_data.left, blur_data.right, blur_data.top, blur_data.bottom, blur_data.clip_radius);
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

                    uint parsed_left = 0, parsed_right = 0, parsed_top = 0, parsed_bottom = 0, parsed_clip_radius = 0;
                    if (
                        uint.try_parse (split_val[0], out parsed_left) &&
                        uint.try_parse (split_val[1], out parsed_right) &&
                        uint.try_parse (split_val[2], out parsed_top) &&
                        uint.try_parse (split_val[3], out parsed_bottom) &&
                        uint.try_parse (split_val[4], out parsed_clip_radius)
                    ) {
                        add_blur (window, parsed_left, parsed_right, parsed_top, parsed_bottom, parsed_clip_radius);
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
