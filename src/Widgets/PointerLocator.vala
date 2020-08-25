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

        private const uint BORDER_WIDTH_PX = 3;

        private const string BACKGROUND_COLOR = "#64baff";
        private const double BACKGROUND_OPACITY = 0.7;

        public weak WindowManager wm { get; construct; }

        private int scaling_factor = 1;

        private GLib.Settings settings;
        private Cogl.Pipeline pipeline;
        private Cairo.Pattern stroke_color;
        private Cairo.Pattern background_color;

        private uint timeout_id;

        public PointerLocator (WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            visible = false;
            reactive = false;

            settings = new GLib.Settings ("org.gnome.desktop.interface");
            pipeline = new Cogl.Pipeline (Clutter.get_default_backend ().get_cogl_context ());

            scaling_factor = InternalUtils.get_ui_scaling_factor ();
            set_size (WIDTH_PX * scaling_factor, HEIGHT_PX * scaling_factor);

            var rgba = Gdk.RGBA ();
            rgba.parse (BACKGROUND_COLOR);
            stroke_color = new Cairo.Pattern.rgb (rgba.red, rgba.green, rgba.blue);
            background_color = new Cairo.Pattern.rgba (rgba.red, rgba.green, rgba.blue, BACKGROUND_OPACITY);
        }

        public override void paint (Clutter.PaintContext context) {
            var width = WIDTH_PX * scaling_factor;
            var height = HEIGHT_PX * scaling_factor;

            var radius = int.min (width / 2, height / 2);

            var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
            var cr = new Cairo.Context (surface);
            cr.set_line_cap (Cairo.LineCap.ROUND);
            cr.set_line_join (Cairo.LineJoin.ROUND);
            cr.translate (width / 2, height / 2);

            cr.move_to (radius - BORDER_WIDTH_PX, 0);
            cr.arc (0, 0, radius - BORDER_WIDTH_PX * scaling_factor, 0, 2 * Math.PI);
            cr.close_path ();

            cr.set_line_width (0);
            cr.set_source (background_color);
            cr.fill_preserve ();

            cr.set_line_width (BORDER_WIDTH_PX * scaling_factor);
            cr.set_source (stroke_color);
            cr.stroke ();

            var cogl_context = context.get_framebuffer ().get_context ();

            var texture = new Cogl.Texture2D.from_data (cogl_context, width, height, Cogl.PixelFormat.BGRA_8888_PRE,
                surface.get_stride (), surface.get_data ());

            pipeline.set_layer_texture (0, texture);

            context.get_framebuffer ().draw_rectangle (pipeline, 0, 0, width, height);

            base.paint (context);
        }

        public void show () {
            if (!settings.get_boolean ("locate-pointer")) {
                return;
            }

            if (timeout_id != 0) {
                GLib.Source.remove (timeout_id);
                timeout_id = 0;
                visible = false;
                restore_easing_state ();
            }

            var tracker = wm.get_display ().get_cursor_tracker ();
            int x, y;
            tracker.get_pointer (out x, out y, null);

            this.x = x - (width / 2);
            this.y = y - (width / 2);

            var pivot = Graphene.Point ();
            pivot.x = 0.5f;
            pivot.y = 0.5f;
            pivot_point = pivot;

            scale_x = 1;
            scale_y = 1;

            visible = true;

            save_easing_state ();
            set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            set_easing_duration (ANIMATION_TIME_MS);

            timeout_id = Timeout.add (ANIMATION_TIME_MS, () => {
                timeout_id = 0;

                restore_easing_state ();

                return GLib.Source.REMOVE;
            });

            scale_x = 0;
            scale_y = 0;
        }
    }
}
