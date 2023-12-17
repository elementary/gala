//
//  Copyright 2020 elementary, Inc. (https://elementary.io)
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
    public class DwellClickTimer : Clutter.Actor, Clutter.Animatable {
        private const double BACKGROUND_OPACITY = 0.7;
        private const int BORDER_WIDTH_PX = 1;

        private const double START_ANGLE = 3 * Math.PI / 2;

        /**
         * Delay, in milliseconds, before showing the animation.
         * libinput uses a timeout of 180ms when tapping is enabled. Use that value plus a safety
         * margin so the animation is never displayed when tapping.
         */
        private const double DELAY_TIMEOUT = 185;

        private float scaling_factor = 1.0f;
        private int cursor_size = 24;

        private Cogl.Pipeline pipeline;
        private Clutter.PropertyTransition transition;
        private Cairo.Pattern stroke_color;
        private Cairo.Pattern fill_color;
        private GLib.Settings interface_settings;
        private Cairo.ImageSurface surface;

        public weak WindowManager wm { get; construct; }

        public double angle { get; set; }

        public DwellClickTimer (WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            visible = false;
            reactive = false;

            pipeline = new Cogl.Pipeline (Clutter.get_default_backend ().get_cogl_context ());

            transition = new Clutter.PropertyTransition ("angle");
            transition.set_progress_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            transition.set_animatable (this);
            transition.set_from_value (START_ANGLE);
            transition.set_to_value (START_ANGLE + (2 * Math.PI));

            transition.new_frame.connect (() => {
                queue_redraw ();
            });

            interface_settings = new GLib.Settings ("org.gnome.desktop.interface");

            var seat = Clutter.get_default_backend ().get_default_seat ();
            seat.set_pointer_a11y_dwell_click_type (Clutter.PointerA11yDwellClickType.PRIMARY);

            seat.ptr_a11y_timeout_started.connect ((device, type, timeout) => {
                unowned var display = wm.get_display ();
                var scale = display.get_monitor_scale (display.get_current_monitor ());
                update_cursor_size (scale);

                unowned var tracker = display.get_cursor_tracker ();
                Graphene.Point coords = {};
                tracker.get_pointer (out coords, null);

                x = coords.x - (width / 2);
                y = coords.y - (width / 2);

                transition.set_duration (timeout);
                visible = true;
                transition.start ();
            });

            seat.ptr_a11y_timeout_stopped.connect ((device, type, clicked) => {
                transition.stop ();
                visible = false;
            });
        }

        private void update_cursor_size (float scale) {
            scaling_factor = scale;

            cursor_size = (int) (interface_settings.get_int ("cursor-size") * scaling_factor * 1.25);

            if (surface == null || surface.get_width () != cursor_size || surface.get_height () != cursor_size) {
                surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, cursor_size, cursor_size);
            }

            set_size (cursor_size, cursor_size);
        }

        public override void paint (Clutter.PaintContext context) {
            if (angle == 0) {
                return;
            }

            var rgba = InternalUtils.get_theme_accent_color ();

            /* Don't use alpha from the stylesheet to ensure contrast */
            stroke_color = new Cairo.Pattern.rgb (rgba.red, rgba.green, rgba.blue);
            fill_color = new Cairo.Pattern.rgba (rgba.red, rgba.green, rgba.blue, BACKGROUND_OPACITY);

            var radius = int.min (cursor_size / 2, cursor_size / 2);
            var end_angle = START_ANGLE + angle;
            var border_width = InternalUtils.scale_to_int (BORDER_WIDTH_PX, scaling_factor);

            var cr = new Cairo.Context (surface);

            // Clear the surface
            cr.save ();
            cr.set_source_rgba (0, 0, 0, 0);
            cr.set_operator (Cairo.Operator.SOURCE);
            cr.paint ();
            cr.restore ();

            cr.set_line_cap (Cairo.LineCap.ROUND);
            cr.set_line_join (Cairo.LineJoin.ROUND);
            cr.translate (cursor_size / 2, cursor_size / 2);

            cr.move_to (0, 0);
            cr.arc (0, 0, radius - border_width, START_ANGLE, end_angle);
            cr.line_to (0, 0);
            cr.close_path ();

            cr.set_line_width (0);
            cr.set_source (fill_color);
            cr.fill_preserve ();

            cr.set_line_width (border_width);
            cr.set_source (stroke_color);
            cr.stroke ();

            var cogl_context = context.get_framebuffer ().get_context ();

            try {
                var texture = new Cogl.Texture2D.from_data (cogl_context, cursor_size, cursor_size, Cogl.PixelFormat.BGRA_8888_PRE,
                    surface.get_stride (), surface.get_data ());

                pipeline.set_layer_texture (0, texture);

                context.get_framebuffer ().draw_rectangle (pipeline, 0, 0, cursor_size, cursor_size);
            } catch (Error e) {}

            base.paint (context);
        }

        public bool interpolate_value (string property_name, Clutter.Interval interval, double progress, out Value @value) {
            if (property_name == "angle") {
                @value = 0;

                var elapsed_time = transition.get_elapsed_time ();
                if (elapsed_time > DELAY_TIMEOUT) {
                    double delayed_progress = (elapsed_time - DELAY_TIMEOUT) / (transition.duration - DELAY_TIMEOUT);
                    @value = (delayed_progress * 2 * Math.PI);
                }

                return true;
            }

            return base.interpolate_value (property_name, interval, progress, out @value);
        }

    }
}
