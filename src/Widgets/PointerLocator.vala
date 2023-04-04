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
    public class PointerLocator : Clutter.Actor, Clutter.Animatable {
        private const int WIDTH_PX = 300;
        private const int HEIGHT_PX = 300;
        private const int ANIMATION_TIME_MS = 300;

        private const int BORDER_WIDTH_PX = 1;

        private const double BACKGROUND_OPACITY = 0.7;

        public weak WindowManager wm { get; construct; }

        private float scaling_factor = 1.0f;
        private int surface_width = WIDTH_PX;
        private int surface_height = HEIGHT_PX;

        private GLib.Settings settings;
        private Cogl.Pipeline pipeline;
        private Cairo.ImageSurface surface;
        private Cairo.Pattern stroke_color;
        private Cairo.Pattern fill_color;

        public PointerLocator (WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            visible = false;
            reactive = false;

            settings = new GLib.Settings ("org.gnome.desktop.interface");
            pipeline = new Cogl.Pipeline (Clutter.get_default_backend ().get_cogl_context ());

            var pivot = Graphene.Point ();
            pivot.init (0.5f, 0.5f);
            pivot_point = pivot;
        }

        private void update_surface (float cur_scale) {
            if (surface == null || cur_scale != scaling_factor) {
                scaling_factor = cur_scale;
                surface_width = InternalUtils.scale_to_int (WIDTH_PX, scaling_factor);
                surface_height = InternalUtils.scale_to_int (HEIGHT_PX, scaling_factor);

                surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, surface_width, surface_height);

                set_size (surface_width, surface_height);
            }
        }

        public override void paint (Clutter.PaintContext context) {
            var radius = int.min (surface_width / 2, surface_height / 2);

            var cr = new Cairo.Context (surface);
            var border_width = InternalUtils.scale_to_int (BORDER_WIDTH_PX, scaling_factor);

            // Clear the surface
            cr.save ();
            cr.set_source_rgba (0, 0, 0, 0);
            cr.set_operator (Cairo.Operator.SOURCE);
            cr.paint ();
            cr.restore ();

            cr.set_line_cap (Cairo.LineCap.ROUND);
            cr.set_line_join (Cairo.LineJoin.ROUND);
            cr.translate (surface_width / 2, surface_height / 2);

            cr.move_to (radius - BORDER_WIDTH_PX, 0);
            cr.arc (0, 0, radius - border_width, 0, 2 * Math.PI);
            cr.close_path ();

            cr.set_line_width (0);
            cr.set_source (fill_color);
            cr.fill_preserve ();

            cr.set_line_width (border_width);
            cr.set_source (stroke_color);
            cr.stroke ();

            var cogl_context = context.get_framebuffer ().get_context ();

            try {
                var texture = new Cogl.Texture2D.from_data (cogl_context, surface_width, surface_height,
                    Cogl.PixelFormat.BGRA_8888_PRE, surface.get_stride (), surface.get_data ());

                pipeline.set_layer_texture (0, texture);

                context.get_framebuffer ().draw_rectangle (pipeline, 0, 0, surface_width, surface_height);
            } catch (Error e) {}

            base.paint (context);
        }

        public void show_ripple () {
            if (!settings.get_boolean ("locate-pointer")) {
                return;
            }

            unowned var old_transition = get_transition ("circle");
            if (old_transition != null) {
                old_transition.stop ();
            }

            var transition = new Clutter.TransitionGroup ();
            transition.remove_on_complete = true;
            var transition_x = new Clutter.PropertyTransition ("scale-x");
            var transition_y = new Clutter.PropertyTransition ("scale-y");
            var start_val = Value (typeof (double));
            start_val.set_double (1);
            var stop_val = Value (typeof (double));
            stop_val.set_double (0);
            transition_x.set_from_value (start_val);
            transition_y.set_from_value (start_val);
            transition_x.set_to_value (stop_val);
            transition_y.set_to_value (stop_val);
            transition.progress_mode = Clutter.AnimationMode.EASE_OUT_QUAD;
            transition.duration = ANIMATION_TIME_MS;
            transition.add_transition (transition_x);
            transition.add_transition (transition_y);
            transition.stopped.connect (() => { visible = false; });
            transition.started.connect (() => { visible = true; });
            add_transition ("circle", transition);

            var rgba = InternalUtils.get_theme_accent_color ();

            /* Don't use alpha from the stylesheet to ensure contrast */
            stroke_color = new Cairo.Pattern.rgb (rgba.red, rgba.green, rgba.blue);
            fill_color = new Cairo.Pattern.rgba (rgba.red, rgba.green, rgba.blue, BACKGROUND_OPACITY);

            unowned var display = wm.get_display ();
            unowned var tracker = display.get_cursor_tracker ();
            Graphene.Point coords = {};
            tracker.get_pointer (out coords, null);

            update_surface (display.get_monitor_scale (display.get_current_monitor ()));

            x = coords.x - (width / 2);
            y = coords.y - (width / 2);

            transition.start ();
        }
    }
}
