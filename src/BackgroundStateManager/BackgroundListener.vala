// TODO: Copyright

public class Gala.BackgroundListener : GLib.Object {
    private const int WALLPAPER_TRANSITION_DURATION = 150;
    private const double ACUTANCE_THRESHOLD = 8;
    private const double STD_THRESHOLD = 45;
    private const double LUMINANCE_THRESHOLD = 180;
    private const double SATURATION_WEIGHT = 1.5;
    private const double WEIGHT_THRESHOLD = 1.0;

    private struct ColorInformation {
        double mean_luminance;
        double luminance_variance;
        double mean_acutance;
    }

    private class DummyOffscreenEffect : Clutter.OffscreenEffect {
        public signal void done_painting ();
        public override void post_paint (Clutter.PaintNode node, Clutter.PaintContext context) {
            base.post_paint (node, context);
            Idle.add (() => {
                done_painting ();
                return false;
            });
        }
    }

    public signal void state_changed (BackgroundState state, uint animation_duration);

    public WindowManager wm { private get; construct; }
    public int panel_height { private get; construct; }

    private unowned Meta.Workspace? current_workspace = null;
    private BackgroundState current_state = BackgroundState.LIGHT;
    private ColorInformation? bk_color_info = null;

    public BackgroundListener (WindowManager wm, int panel_height) {
        Object (wm: wm, panel_height: panel_height);
    }

    construct {
        connect_signals ();
        update_bk_color_info.begin ((obj, res) => {
            update_bk_color_info.end (res);
            update_current_workspace ();
        });
    }

    private void connect_signals () {
        unowned var manager = wm.get_display ().get_workspace_manager ();
        manager.workspace_switched.connect (update_current_workspace);

        ((BackgroundContainer) wm.background_group).changed.connect (() => {
            update_bk_color_info.begin ((obj, res) => {
                update_bk_color_info.end (res);
                check_for_state_change (WALLPAPER_TRANSITION_DURATION);
            });
        });
    }

    private void update_current_workspace () {
        unowned Meta.WorkspaceManager manager = wm.get_display ().get_workspace_manager ();
        unowned var workspace = manager.get_active_workspace ();

        if (workspace == null) {
            warning ("Cannot get active workspace");

            return;
        }

        if (current_workspace != null) {
            current_workspace.window_added.disconnect (on_window_added);
            current_workspace.window_removed.disconnect (on_window_removed);
        }

        current_workspace = workspace;

        foreach (unowned Meta.Window window in current_workspace.list_windows ()) {
            if (window.is_on_primary_monitor ()) {
                register_window (window);
            }
        }

        current_workspace.window_added.connect (on_window_added);
        current_workspace.window_removed.connect (on_window_removed);

        check_for_state_change (AnimationDuration.WORKSPACE_SWITCH_MIN);
    }

    private void register_window (Meta.Window window) {
        window.notify["maximized-vertically"].connect (() => {
            check_for_state_change (AnimationDuration.SNAP);
        });

        window.notify["minimized"].connect (() => {
            check_for_state_change (AnimationDuration.HIDE);
        });

        window.workspace_changed.connect (() => {
            check_for_state_change (AnimationDuration.WORKSPACE_SWITCH_MIN);
        });
    }

    private void on_window_added (Meta.Window window) {
        register_window (window);

        check_for_state_change (AnimationDuration.SNAP);
    }

    private void on_window_removed (Meta.Window window) {
        check_for_state_change (AnimationDuration.SNAP);
    }

    public async void update_bk_color_info () {
        SourceFunc callback = update_bk_color_info.callback;

        unowned var display = wm.get_display ();
        var monitor_geometry = display.get_monitor_geometry (display.get_primary_monitor ());

        get_background_color_information.begin (0, 0, monitor_geometry.width, panel_height, (obj, res) => {
            bk_color_info = get_background_color_information.end (res);

            callback ();
        });

        yield;
    }


    private async ColorInformation? get_background_color_information (int reference_x, int reference_y, int reference_width, int reference_height) {
        var monitor = wm.get_display ().get_primary_monitor ();
        var bg_manager = (Gala.BackgroundManagerInterface) wm.background_group.get_child_at_index (monitor);
    
        if (bg_manager == null) {
            critical ("Invalid monitor requested: %i", monitor);
            return null;
        }
    
        var effect = new DummyOffscreenEffect ();
        unowned var newest_background_actor = bg_manager.newest_background_actor;
        newest_background_actor.add_effect (effect);
    
        var bg_actor_width = (int) newest_background_actor.width;
        var bg_actor_height = (int) newest_background_actor.height;
    
        // A commit in mutter added some padding to offscreen textures, so we
        // need to avoid looking at the edges of the texture as it often has a
        // black border. The commit specifies that up to 1.75px around each side
        // could now be padding, so cut off 2px from left and top if necessary
        // (https://gitlab.gnome.org/GNOME/mutter/commit/8655bc5d8de6a969e0ca83eff8e450f62d28fbee)
        int x_start = reference_x;
        if (x_start < 2) {
            x_start = 2;
        }
    
        int y_start = reference_y;
        if (y_start < 2) {
            y_start = 2;
        }
    
        // For the same reason as above, we need to not use the bottom and right
        // 2px of the texture. However, if the caller has specified an area of
        // interest that already misses these parts, use that instead, otherwise
        // chop 2px
        int width = int.min (bg_actor_width - 2 - reference_x, reference_width);
        int height = int.min (bg_actor_height - 2 - reference_y, reference_height);
    
        if (x_start > bg_actor_width || y_start > bg_actor_height || width <= 0 || height <= 0) {
            critical ("Invalid rectangle specified: %i, %i, %i, %i", x_start, y_start, width, height);
            return null;
        }
    
        double mean_acutance = 0, variance = 0, mean = 0, r_total = 0, g_total = 0, b_total = 0;
        ulong paint_signal_handler = 0;
    
        paint_signal_handler = effect.done_painting.connect (() => {
            SignalHandler.disconnect (effect, paint_signal_handler);
            newest_background_actor.remove_effect (effect);
    
            var texture = (Cogl.Texture)effect.get_texture ();
            var texture_width = texture.get_width ();
            var texture_height = texture.get_height ();
    
            var pixels = new uint8[texture_width * texture_height * 4];
            var pixel_lums = new double[texture_width * texture_height];
    
            texture.get_data (Cogl.PixelFormat.BGRA_8888_PRE, 0, pixels);
    
            int size = width * height;
    
            double mean_squares = 0;
            double pixel = 0;
    
            double max, min, score, delta, score_total = 0, r_total2 = 0, g_total2 = 0, b_total2 = 0;
    
            /*
            * code to calculate weighted average color is copied from
            * plank's lib/Drawing/DrawingService.vala average_color()
            * http://bazaar.launchpad.net/~docky-core/plank/trunk/view/head:/lib/Drawing/DrawingService.vala
            */
            for (int y = y_start; y < (y_start + height); y++) {
                for (int x = x_start; x < (x_start + width); x++) {
                    int i = (y * (int)texture_width * 4) + (x * 4);
    
                    uint8 b = pixels[i];
                    uint8 g = pixels[i + 1];
                    uint8 r = pixels[i + 2];
    
                    pixel = (0.3 * r + 0.59 * g + 0.11 * b) ;
    
                    pixel_lums[y * width + x] = pixel;
    
                    min = uint8.min (r, uint8.min (g, b));
                    max = uint8.max (r, uint8.max (g, b));
    
                    delta = max - min;
    
                    /* prefer colored pixels over shades of grey */
                    score = SATURATION_WEIGHT * (delta == 0 ? 0.0 : delta / max);
    
                    r_total += score * r;
                    g_total += score * g;
                    b_total += score * b;
                    score_total += score;
    
                    r_total += r;
                    g_total += g;
                    b_total += b;
    
                    mean += pixel;
                    mean_squares += pixel * pixel;
                }
            }
    
            for (int y = y_start + 1; y < (y_start + height) - 1; y++) {
                for (int x = x_start + 1; x < (x_start + width) - 1; x++) {
                    var acutance =
                        (pixel_lums[y * width + x] * 4) -
                        (
                            pixel_lums[y * width + x - 1] +
                            pixel_lums[y * width + x + 1] +
                            pixel_lums[(y - 1) * width + x] +
                            pixel_lums[(y + 1) * width + x]
                        );
    
                    mean_acutance += acutance > 0 ? acutance : -acutance;
                }
            }
    
            score_total /= size;
            b_total /= size;
            g_total /= size;
            r_total /= size;
    
            if (score_total > 0.0) {
                b_total /= score_total;
                g_total /= score_total;
                r_total /= score_total;
            }
    
            b_total2 /= size * uint8.MAX;
            g_total2 /= size * uint8.MAX;
            r_total2 /= size * uint8.MAX;
    
            /*
                * combine weighted and not weighted sum depending on the average "saturation"
                * if saturation isn't reasonable enough
                * s = 0.0 -> f = 0.0 ; s = WEIGHT_THRESHOLD -> f = 1.0
                */
            if (score_total <= WEIGHT_THRESHOLD) {
                var f = 1.0 / WEIGHT_THRESHOLD * score_total;
                var rf = 1.0 - f;
    
                b_total = b_total * f + b_total2 * rf;
                g_total = g_total * f + g_total2 * rf;
                r_total = r_total * f + r_total2 * rf;
            }
    
            /* there shouldn't be values larger then 1.0 */
            var max_val = double.max (r_total, double.max (g_total, b_total));
    
            if (max_val > 1.0) {
                b_total /= max_val;
                g_total /= max_val;
                r_total /= max_val;
            }
    
            mean /= size;
            mean_squares = mean_squares / size;
    
            variance = (mean_squares - (mean * mean));
    
            mean_acutance /= (width - 2) * (height - 2);
    
            get_background_color_information.callback ();
        });
    
        newest_background_actor.queue_redraw ();
    
        yield;
    
        return { mean, variance, mean_acutance };
    }

    /**
     * Check if Wingpanel's background state should change.
     *
     * The state is defined as follows:
     *  - If there's a maximized window, the state should be MAXIMIZED;
     *  - If no information about the background could be gathered, it should be TRANSLUCENT;
     *  - If there's too much contrast or sharpness, it should be TRANSLUCENT;
     *  - If the background is too bright, it should be DARK;
     *  - Else it should be LIGHT.
     */
    private void check_for_state_change (uint animation_duration) {
        bool has_maximized_window = false;

        foreach (unowned Meta.Window window in current_workspace.list_windows ()) {
            if (window.is_on_primary_monitor ()) {
                if (!window.minimized && window.maximized_vertically) {
                    has_maximized_window = true;
                    break;
                }
            }
        }

        BackgroundState new_state;

        if (has_maximized_window) {
            new_state = BackgroundState.MAXIMIZED;
        } else if (bk_color_info == null) {
            new_state = BackgroundState.TRANSLUCENT_LIGHT;
        } else {
            var luminance_std = Math.sqrt (bk_color_info.luminance_variance);

            bool bg_is_busy = luminance_std > STD_THRESHOLD ||
                (bk_color_info.mean_luminance < LUMINANCE_THRESHOLD &&
                bk_color_info.mean_luminance + 1.645 * luminance_std > LUMINANCE_THRESHOLD ) ||
                bk_color_info.mean_acutance > ACUTANCE_THRESHOLD;

            bool bg_is_dark = bk_color_info.mean_luminance > LUMINANCE_THRESHOLD;
            bool bg_is_busy_dark = bk_color_info.mean_luminance * 1.25 > LUMINANCE_THRESHOLD;

            if (bg_is_busy && bg_is_busy_dark) {
                new_state = BackgroundState.TRANSLUCENT_DARK;
            } else if (bg_is_busy) {
                new_state = BackgroundState.TRANSLUCENT_LIGHT;
            } else if (bg_is_dark) {
                new_state = BackgroundState.DARK;
            } else {
                new_state = BackgroundState.LIGHT;
            }
        }

        if (new_state != current_state) {
            state_changed (current_state = new_state, animation_duration);
        }
    }
}
