//
//  Copyright (C) 2012 - 2014 Tom Beckmann, Jacob Parker
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Gala {
    [DBus (name="org.pantheon.gala")]
    public class DBus {
        static DBus? instance;
        static WindowManager wm;
        Clutter.DragAction drag_action;
        Clutter.Actor icon;
        ulong preview_handler_id = 0UL;

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
                Bus.own_name (BusType.SESSION, "org.freedesktop.ScreenSaver", BusNameOwnerFlags.REPLACE,
                    (connection) => {
                        try {
                            connection.register_object ("/org/freedesktop/ScreenSaver", screensaver_manager);
                        } catch (Error e) { warning (e.message); }
                    },
                    () => {},
                    () => critical ("Could not acquire freedesktop ScreenSaver bus") );

                Bus.own_name (BusType.SESSION, "org.gnome.ScreenSaver", BusNameOwnerFlags.REPLACE,
                    (connection) => {
                        try {
                            connection.register_object ("/org/gnome/ScreenSaver", screensaver_manager.gnome_manager);
                        } catch (Error e) { warning (e.message); }
                    },
                    () => {},
                    () => critical ("Could not acquire ScreenSaver bus") );
            }
        }

        private DBus () {
            if (wm.background_group != null)
                (wm.background_group as BackgroundContainer).changed.connect (() => background_changed ());
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
#if HAS_MUTTER336
            public override void post_paint (Clutter.PaintContext context) {
                base.post_paint (context);
#else
            public override void post_paint () {
                base.post_paint ();
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

        public void show_preview () throws Error {
            debug("show launch preview!");
            unowned Meta.Display display = wm.get_display ();

            unowned Meta.Window? dock_window = null;
            foreach (unowned Meta.WindowActor actor in display.get_window_actors ()) {
                dock_window = actor.get_meta_window ();
                if (dock_window.title == "plank") {
                    break;
                }
            }

            if (dock_window == null) {
                return;
            }

            unowned Meta.CursorTracker ct = display.get_cursor_tracker ();
            int x, y;
            Clutter.ModifierType type;
            ct.get_pointer (out x, out y, out type);
            unowned WindowManagerGala? gala_wm = wm as WindowManagerGala;
            gala_wm.area_tiling.is_active = true;
            Meta.Rectangle tile_rect;
            gala_wm.area_tiling.calculate_tile_rect (out tile_rect, dock_window, x, y);
            wm.show_tile_preview (dock_window, tile_rect, display.get_current_monitor ());

            drag_action = new Clutter.DragAction ();
            drag_action.drag_motion.connect (() => debug("drag_motion!"));
            drag_action.drag_begin.connect (() => debug("begin this drag aciton!!!!"));
            drag_action.drag_end.connect (() => debug("end this drag aciton!!!!"));
            icon = wm.stage.get_actor_at_pos (Clutter.PickMode.REACTIVE, x, y);
            icon.reactive = true;
            icon.add_action (drag_action);

            drag_action.drag_begin (icon, (float)x, (float)y, type);

            //  resize_handle.set_size (button_size, button_size);
            //  resize_handle.set_pivot_point (0.5f, 0.5f);
            //  resize_handle.set_position (width - button_size, height - button_size);

            //  preview_handler_id = dock_window.get_actor () .captured_event.connect (event => {
            //      debug("capture evenet");
            //      if (event.get_type () == Clutter.EventType.MOTION) {
            //          debug("motion");
            //          return true;
            //      }
            //      return false;
            //  });
            //  preview_handler_id = icon.motion_event.connect (event => {
            //      debug("motion!");
            //      return false;
            //  });
            //  preview_handler_id = ct.cursor_moved.connect ((fx, fy) => {
            //      debug("cursor move!");
            //      gala_wm.area_tiling.calculate_tile_rect (out tile_rect, dock_window, (int)fx, (int)fy);
            //      wm.show_tile_preview (dock_window, tile_rect, display.get_current_monitor ());
            //  });
        }

        public void hide_preview () throws Error {
            debug("hide launch preview!");
            unowned WindowManagerGala? gala_wm = wm as WindowManagerGala;
            gala_wm.area_tiling.is_active = false;
            //  wm.stage.disconnect (preview_handler_id);
            wm.hide_tile_preview ();

            int x, y;
            Clutter.ModifierType type;
            wm.get_display ().get_cursor_tracker ().get_pointer (out x, out y, out type);
            drag_action.drag_end (icon, (float)x, (float)y, type);
        }

        /**
         * Emitted when the background change occured and the transition ended.
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
                   rTotal = 0, gTotal = 0, bTotal = 0;

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

                double max, min, score, delta, scoreTotal = 0,
                       rTotal2 = 0, gTotal2 = 0, bTotal2 = 0;

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

                        rTotal += score * r;
                        gTotal += score * g;
                        bTotal += score * b;
                        scoreTotal += score;

                        rTotal += r;
                        gTotal += g;
                        bTotal += b;

                        mean += pixel;
                        mean_squares += pixel * pixel;
                    }
                }

                scoreTotal /= size;
                bTotal /= size;
                gTotal /= size;
                rTotal /= size;

                if (scoreTotal > 0.0) {
                    bTotal /= scoreTotal;
                    gTotal /= scoreTotal;
                    rTotal /= scoreTotal;
                }

                bTotal2 /= size * uint8.MAX;
                gTotal2 /= size * uint8.MAX;
                rTotal2 /= size * uint8.MAX;

                // combine weighted and not weighted sum depending on the average "saturation"
                // if saturation isn't reasonable enough
                // s = 0.0 -> f = 0.0 ; s = WEIGHT_THRESHOLD -> f = 1.0
                if (scoreTotal <= WEIGHT_THRESHOLD) {
                    var f = 1.0 / WEIGHT_THRESHOLD * scoreTotal;
                    var rf = 1.0 - f;
                    bTotal = bTotal * f + bTotal2 * rf;
                    gTotal = gTotal * f + gTotal2 * rf;
                    rTotal = rTotal * f + rTotal2 * rf;
                }

                // there shouldn't be values larger then 1.0
                var max_val = double.max (rTotal, double.max (gTotal, bTotal));
                if (max_val > 1.0) {
                    bTotal /= max_val;
                    gTotal /= max_val;
                    rTotal /= max_val;
                }

                mean /= size;
                mean_squares *= mean_squares / size;

                variance = Math.sqrt (mean_squares - mean * mean) / (double) size;

                get_background_color_information.callback ();
            });

            background.queue_redraw ();

            yield;

            return { rTotal, gTotal, bTotal, mean, variance };
        }
    }
}
