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
        private const string BACKGROUND_COLOR = "#64baff";
        private const double BACKGROUND_OPACITY = 0.7;
        private const uint BORDER_WIDTH_PX = 1;

        private const double START_ANGLE = 3 * Math.PI / 2;

        private int scaling_factor = 1;
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

            var rgba = Gdk.RGBA ();
            rgba.parse (BACKGROUND_COLOR);
            stroke_color = new Cairo.Pattern.rgb (rgba.red, rgba.green, rgba.blue);
            fill_color = new Cairo.Pattern.rgba (rgba.red, rgba.green, rgba.blue, BACKGROUND_OPACITY);

            interface_settings = new GLib.Settings ("org.gnome.desktop.interface");
            scaling_factor = InternalUtils.get_ui_scaling_factor ();

            update_cursor_size ();

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

            interface_settings.changed["cursor-size"].connect (() => {
                update_cursor_size ();
            });
        }

        private void update_cursor_size () {
            cursor_size = (int) (interface_settings.get_int ("cursor-size") * scaling_factor * 1.25);
            surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, cursor_size, cursor_size);
            set_size (cursor_size, cursor_size);
        }

        public override void paint (Clutter.PaintContext context) {
            var radius = int.min (cursor_size / 2, cursor_size / 2);
            var end_angle = START_ANGLE + angle;

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
            cr.arc (0, 0, radius - BORDER_WIDTH_PX * scaling_factor, START_ANGLE, end_angle);
            cr.line_to (0, 0);
            cr.close_path ();

            cr.set_line_width (0);
            cr.set_source (fill_color);
            cr.fill_preserve ();

            cr.set_line_width (BORDER_WIDTH_PX * scaling_factor);
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
                @value = progress * 2 * Math.PI;
                return true;
            }

            return base.interpolate_value (property_name, interval, progress, out @value);
        }

    }
}
