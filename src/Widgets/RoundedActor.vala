/*
 * Copyright 2017 Popye <sailor3101@gmail.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public class RoundedActor : Clutter.Actor {
        private Clutter.Canvas canvas;
        public Clutter.Color back_color { get; protected set; }
        public int rect_radius { get; protected set; }

        public RoundedActor (Clutter.Color background_color, int radius) {
            Object (
                back_color: background_color,
                rect_radius: radius
            );
        }

        construct {
            canvas = new Clutter.Canvas ();
            this.set_content (canvas);
            canvas.draw.connect (this.drawit);
        }

        protected virtual bool drawit (Cairo.Context ctx) {
            Granite.Drawing.BufferSurface buffer;
            buffer = new Granite.Drawing.BufferSurface ((int)this.width, (int)this.height);

            /*
            * copied from popover-granite-drawing
            * https://code.launchpad.net/~tombeckmann/wingpanel/popover-granite-drawing
            */

            buffer.context.clip ();
            buffer.context.reset_clip ();

            // draw rect
            Clutter.cairo_set_source_color (buffer.context, back_color);
            Granite.Drawing.Utilities.cairo_rounded_rectangle (buffer.context, 0, 0, (int)this.width, (int)this.height, rect_radius);
            buffer.context.fill ();

            //clear surface to transparent
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.set_source_rgba (0, 0, 0, 0);
            ctx.paint ();

            //now paint our buffer on
            ctx.set_source_surface (buffer.surface, 0, 0);
            ctx.paint ();

            return true;
        }

        public void resize (int width, int height) {
            set_size (width, height);
            canvas.set_size (width, height);
            canvas.invalidate ();
        }
    }
}
