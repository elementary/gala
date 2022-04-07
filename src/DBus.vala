/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 *           2012–2014 Tom Beckmann, Jacob Parker
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gala {
    [DBus (name = "org.freedesktop.DBus")]
    private interface FreedesktopDBus : Object {
        [DBus (name = "GetConnectionUnixProcessID")]
        public abstract uint32 get_connection_unix_process_id (string name) throws Error;
    }

    private class TextureActor : Clutter.Actor {
        private static Clutter.Color transparent_color;
        private Cogl.Texture texture;

        public TextureActor (Cogl.Texture tex) {
            this.texture = tex;
        }

        static construct {
            transparent_color = Clutter.Color.alloc ();
            transparent_color.red = transparent_color.green = transparent_color.blue = 255;
        }

        public override void paint_node (Clutter.PaintNode root) {
            var box = get_allocation_box ();

            transparent_color.alpha = get_paint_opacity ();
            var tex_node = new Clutter.TextureNode (texture, transparent_color, Clutter.ScalingFilter.TRILINEAR, Clutter.ScalingFilter.LINEAR);
            tex_node.add_rectangle (box);

            root.add_child (tex_node);
        }
    }

    [DBus (name="org.pantheon.gala")]
    public class DBus {
        static DBus? instance;
        static WindowManager wm;
        static FreedesktopDBus? bus_proxy;

        static Cogl.Pipeline? copy_pipeline = null;

        [DBus (visible = false)]
        public static void init (WindowManager _wm) {
            wm = _wm;

            Bus.own_name (BusType.SESSION, "org.pantheon.gala", BusNameOwnerFlags.NONE,
                (connection) => {
                    if (instance == null)
                        instance = new DBus ();

                    try {
                        connection.register_object ("/org/pantheon/gala", instance);
                    } catch (Error e) { warning (e.message); }
                },
                () => {},
                () => warning ("Could not acquire name\n") );

            Bus.own_name (BusType.SESSION, "org.gnome.Shell", BusNameOwnerFlags.NONE,
                (connection) => {
                    try {
                        connection.register_object ("/org/gnome/Shell", DBusAccelerator.init (wm));
                        connection.register_object ("/org/gnome/Shell/Screenshot", ScreenshotManager.init (wm));
                    } catch (Error e) { warning (e.message); }
                },
                () => {},
                () => critical ("Could not acquire name") );

            Bus.own_name (BusType.SESSION, "org.gnome.Shell.Screenshot", BusNameOwnerFlags.REPLACE,
                () => {},
                () => {},
                () => critical ("Could not acquire name") );

            Bus.own_name (BusType.SESSION, "org.gnome.SessionManager.EndSessionDialog", BusNameOwnerFlags.NONE,
                (connection) => {
                    try {
                        connection.register_object ("/org/gnome/SessionManager/EndSessionDialog", SessionManager.init ());
                    } catch (Error e) { warning (e.message); }
                },
                () => {},
                () => critical ("Could not acquire name") );

            unowned WindowManagerGala? gala_wm = wm as WindowManagerGala;
            if (gala_wm != null) {
                var screensaver_manager = gala_wm.screensaver;

                Bus.own_name (BusType.SESSION, "org.gnome.ScreenSaver", BusNameOwnerFlags.REPLACE,
                    (connection) => {
                        try {
                            connection.register_object ("/org/gnome/ScreenSaver", screensaver_manager);
                        } catch (Error e) { warning (e.message); }
                    },
                    () => {},
                    () => critical ("Could not acquire ScreenSaver bus") );
            }

            try {
                bus_proxy = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.DBus", "/");
            } catch (Error e) {
                warning (e.message);
                bus_proxy = null;
            }
        }

        private DBus () {
            if (wm.background_group != null)
                ((BackgroundContainer) wm.background_group).changed.connect (() => background_changed ());
            else
                assert_not_reached ();
        }

        public void perform_action (ActionType type) throws DBusError, IOError {
            wm.perform_action (type);
        }

        const double SATURATION_WEIGHT = 1.5;
        const double WEIGHT_THRESHOLD = 1.0;

        class DummyOffscreenEffect : Clutter.OffscreenEffect {
            public signal void done_painting ();

#if HAS_MUTTER40
            public override void post_paint (Clutter.PaintNode node, Clutter.PaintContext context) {
                base.post_paint (node, context);
#else
            public override void post_paint (Clutter.PaintContext context) {
                base.post_paint (context);
#endif
                done_painting ();
            }
        }

        public struct ColorInformation {
            double average_red;
            double average_green;
            double average_blue;
            double mean;
            double variance;
        }

        /**
         * Emitted when the background change occurred and the transition ended.
         * You can safely call get_optimal_panel_alpha then. It is not guaranteed
         * that this signal will be emitted only once per group of changes as often
         * done by GUIs. The change may not be visible to the user.
         */
        public signal void background_changed ();

        /**
         * Attaches a dummy offscreen effect to the background at monitor to get its
         * isolated color data. Then calculate the red, green and blue components of
         * the average color in that area and the mean color value and variance. All
         * variables are returned as a tuple in that order.
         *
         * @param monitor          The monitor where the panel will be placed
         * @param reference_x      X coordinate of the rectangle used to gather color data
         *                         relative to the monitor you picked. Values will be clamped
         *                         to its dimensions
         * @param reference_y      Y coordinate
         * @param reference_width  Width of the rectangle
         * @param reference_height Height of the rectangle
         */
        public async ColorInformation get_background_color_information (int monitor,
            int reference_x, int reference_y, int reference_width, int reference_height)
            throws DBusError, IOError {
            var background = wm.background_group.get_child_at_index (monitor);
            if (background == null)
                throw new DBusError.INVALID_ARGS ("Invalid monitor requested");

            var effect = new DummyOffscreenEffect ();
            background.add_effect (effect);

            var tex_width = (int)background.width;
            var tex_height = (int)background.height;

            int x_start = reference_x;
            int y_start = reference_y;
            int width = int.min (tex_width - reference_x, reference_width);
            int height = int.min (tex_height - reference_y, reference_height);

            if (x_start > tex_width || x_start > tex_height || width <= 0 || height <= 0)
                throw new DBusError.INVALID_ARGS ("Invalid rectangle specified");

            double variance = 0, mean = 0,
                   r_total = 0, g_total = 0, b_total = 0;

            ulong paint_signal_handler = 0;
            paint_signal_handler = effect.done_painting.connect (() => {
                SignalHandler.disconnect (effect, paint_signal_handler);
                background.remove_effect (effect);

                var texture = (Cogl.Texture)effect.get_texture ();
                var pixels = new uint8[texture.get_width () * texture.get_height () * 4];
                texture.get_data (Cogl.PixelFormat.BGRA_8888_PRE, 0, pixels);

                int size = width * height;

                double mean_squares = 0;
                double pixel = 0;

                double max, min, score, delta, score_total = 0,
                       r_total2 = 0, g_total2 = 0, b_total2 = 0;

                // code to calculate weighted average color is copied from
                // plank's lib/Drawing/DrawingService.vala average_color()
                // http://bazaar.launchpad.net/~docky-core/plank/trunk/view/head:/lib/Drawing/DrawingService.vala
                for (int y = y_start; y < height; y++) {
                    for (int x = x_start; x < width; x++) {
                        int i = y * width * 4 + x * 4;

                        uint8 r = pixels[i];
                        uint8 g = pixels[i + 1];
                        uint8 b = pixels[i + 2];

                        pixel = (0.3 * r + 0.6 * g + 0.11 * b) - 128f;

                        min = uint8.min (r, uint8.min (g, b));
                        max = uint8.max (r, uint8.max (g, b));
                        delta = max - min;

                        // prefer colored pixels over shades of grey
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

                // combine weighted and not weighted sum depending on the average "saturation"
                // if saturation isn't reasonable enough
                // s = 0.0 -> f = 0.0 ; s = WEIGHT_THRESHOLD -> f = 1.0
                if (score_total <= WEIGHT_THRESHOLD) {
                    var f = 1.0 / WEIGHT_THRESHOLD * score_total;
                    var rf = 1.0 - f;
                    b_total = b_total * f + b_total2 * rf;
                    g_total = g_total * f + g_total2 * rf;
                    r_total = r_total * f + r_total2 * rf;
                }

                // there shouldn't be values larger then 1.0
                var max_val = double.max (r_total, double.max (g_total, b_total));
                if (max_val > 1.0) {
                    b_total /= max_val;
                    g_total /= max_val;
                    r_total /= max_val;
                }

                mean /= size;
                mean_squares *= mean_squares / size;

                variance = Math.sqrt (mean_squares - mean * mean) / (double) size;

                get_background_color_information.callback ();
            });

            background.queue_redraw ();

            yield;

            return { r_total, g_total, b_total, mean, variance };
        }

        /**
         * Creates a window snapshot and transitions from it to the real state.
         *
         * Calling this method will create a static temporary snapshot from a target window
         * and will transition from it to the real window surface. This is useful if
         * e.g you want to change the Gtk stylesheet used by your application.
         * It can be used to create a smooth transition effect when switching to the new
         * stylesheet. If that's your intention, call this function just before actually changing
         * the stylesheet for the best effect.
         *
         * The function will create a transition animation only when animations are enabled.
         * If they are not, the animation will not be visible but the snapshot will be still created and added.
         *
         * The transition will be applied to all windows that belong to your process ID.
         *
         * Note that you will not be able to affect any windows that do
         * not belong to your PID, this is reserved for system components.
         */
        public async void transition_from_snapshot (BusName sender) throws IOError {
            if (bus_proxy == null) {
                throw new IOError.FAILED ("Could not connect to org.freedesktop.DBus");
            }

            uint32 pid = bus_proxy.get_connection_unix_process_id (sender);
            bool animate = wm.enable_animations;

            foreach (unowned Meta.WindowActor actor in wm.get_display ().get_window_actors ()) {
                unowned Meta.Window window = actor.get_meta_window ();
                if (window.get_pid () == pid) {
                    yield transition_window (actor.get_meta_window (), animate);
                }
            }
        }

        /**
         * Creates a window snapshot and transitions from it to the real state
         * for all windows on the visible workspace. See transition_from_snapshot.
         *
         * This function is reserved for system components and must not be
         * accessed by applications.
         */
        public async void global_transition_from_snapshot () throws IOError {
            bool animate = wm.enable_animations;

            unowned Meta.Workspace workspace = wm.get_display ().get_workspace_manager ().get_active_workspace ();
            var windows = workspace.list_windows ();
            foreach (unowned Meta.Window window in windows) {
                if (!window.minimized && window.get_window_type () != Meta.WindowType.DESKTOP) {
                    yield transition_window (window, animate);
                }
            }
        }

        static async void transition_window (Meta.Window window, bool animate) {
            /**
             * Because Gtk takes time to apply the styling to all elements,
             * we will simply define an arbitrary wait time for this to happen
             * to smoothen out the transition.
             */
            const uint STYLE_CHANGE_COMPLETION_DURATION = 300;

            unowned Meta.WindowActor actor = (Meta.WindowActor)window.get_compositor_private ();

            var rect = window.get_frame_rect ();
            int x_offset = rect.x - (int) actor.x;
            int y_offset = rect.y - (int) actor.y;

            var texture = ((Meta.ShapedTexture)actor.get_texture ()).get_texture ();
            texture = fast_copy_texture (texture, x_offset, y_offset, rect.width, rect.height, Cogl.PixelFormat.BGRA_8888_PRE);

            var snapshot = new TextureActor (texture);
            snapshot.set_position ((float)x_offset / 2.0f, (float)y_offset / 2.0f);
            snapshot.set_size (rect.width, rect.height);
            actor.insert_child_above (snapshot, null);

            Timeout.add (STYLE_CHANGE_COMPLETION_DURATION, () => {
                if (animate) {
                    snapshot.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
                    snapshot.set_easing_duration (AnimationDuration.STYLE_SWITCH);
                    snapshot.opacity = 0;

                    ulong signal_id = 0U;
                    signal_id = snapshot.transitions_completed.connect (() => {
                        snapshot.disconnect (signal_id);
                        snapshot.destroy ();
                    });
                } else {
                    snapshot.opacity = 0;
                    Timeout.add (AnimationDuration.STYLE_SWITCH, () => {
                        snapshot.destroy ();
                        return Source.REMOVE;
                    });
                }

                return Source.REMOVE;
            });

        }

        static Cogl.Texture fast_copy_texture (Cogl.Texture texture, int xoff, int yoff, int width, int height, Cogl.PixelFormat format) {
            var copy = Cogl.Texture.new_with_size (width, height, Cogl.TextureFlags.NONE, format);

            if (copy_pipeline == null) {
                unowned Cogl.Context context = Clutter.get_default_backend ().get_cogl_context ();
                copy_pipeline = new Cogl.Pipeline (context);
            }

            copy_pipeline.set_layer_texture (0, texture);

            var fbo = new Cogl.Offscreen.with_texture (copy);
            fbo.draw_textured_rectangle (copy_pipeline,
                -1, -1, 1, 1,
                xoff / (float)texture.get_width (),
                (yoff + height) / (float)texture.get_height (),
                (xoff + width) / (float)texture.get_width (),
                yoff / (float)texture.get_height ());

            return copy;
        }
    }
}
