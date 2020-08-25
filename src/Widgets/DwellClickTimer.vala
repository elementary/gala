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
        private const int WIDTH_PX = 60;
        private const int HEIGHT_PX = 60;

        private const uint BORDER_WIDTH_PX = 3;

        private const double START_ANGLE = 3 * Math.PI / 2;

        private int scaling_factor = 1;

        private Cogl.Pipeline pipeline;
        private Clutter.PropertyTransition transition;

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

            scaling_factor = InternalUtils.get_ui_scaling_factor ();
            set_size (WIDTH_PX * scaling_factor, HEIGHT_PX * scaling_factor);

            var seat = Clutter.get_default_backend ().get_default_seat ();
            seat.set_pointer_a11y_dwell_click_type (Clutter.PointerA11yDwellClickType.PRIMARY);

            seat.ptr_a11y_timeout_started.connect ((device, type, timeout) => {
                var tracker = wm.get_display ().get_cursor_tracker ();
                int x, y;
                tracker.get_pointer (out x, out y, null);

                this.x = x - (width / 2);
                this.y = y - (width / 2);

                transition.set_duration (timeout);
                visible = true;
                transition.start ();
            });

            seat.ptr_a11y_timeout_stopped.connect ((device, type, clicked) => {
                transition.stop ();
                visible = false;
            });
        }

        public override void paint (Clutter.PaintContext context) {
            var width = WIDTH_PX * scaling_factor;
            var height = HEIGHT_PX * scaling_factor;

            var radius = int.min (width / 2, height / 2);
            var end_angle = START_ANGLE + angle;

            var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
            var cr = new Cairo.Context (surface);
            cr.set_line_cap (Cairo.LineCap.ROUND);
            cr.set_line_join (Cairo.LineJoin.ROUND);
            cr.translate (width / 2, height / 2);

            cr.move_to (0, 0);
            cr.arc (0, 0, radius - BORDER_WIDTH_PX * scaling_factor, START_ANGLE, end_angle);
            cr.line_to (0, 0);
            cr.close_path ();

            cr.set_line_width (0);
            cr.set_source_rgba (0.278, 0.561, 0.902, 0.7);
            cr.fill_preserve ();

            cr.set_line_width (BORDER_WIDTH_PX * scaling_factor);
            cr.set_source_rgb (0.278, 0.561, 0.902);
            cr.stroke ();

            var cogl_context = context.get_framebuffer ().get_context ();

            var texture = new Cogl.Texture2D.from_data (cogl_context, width, height, Cogl.PixelFormat.BGRA_8888_PRE,
                surface.get_stride (), surface.get_data ());

            pipeline.set_layer_texture (0, texture);

            context.get_framebuffer ().draw_rectangle (pipeline, 0, 0, width, height);

            base.paint (context);
        }

        public bool interpolate_value (string property_name, Clutter.Interval interval, double progress, out Value @value) {
            if (property_name == "angle") {
                @value = progress * 2 * Math.PI;
                return true;
            }

            return base.interpolate_value (property_name, interval, progress, out @value);
        }

    }
}
