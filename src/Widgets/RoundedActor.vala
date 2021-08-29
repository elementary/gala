//  Copyright (C) 2017, Popye [sailor3101@gmail.com]
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

using Clutter;
using Meta;

namespace Gala.Plugins.Catts
{
    class RoundedActor : Actor
    {
        private Canvas canvas;
        private Color back_color;
        private int rect_radius;

        public RoundedActor (Color background_color, int radius)
        {
            rect_radius = radius;
            back_color = background_color;
            canvas = new Canvas ();
            this.set_content (canvas);
            canvas.draw.connect (this.drawit);
        }

        protected virtual bool drawit ( Cairo.Context ctx)
        {
            Granite.Drawing.BufferSurface buffer;
            buffer = new Granite.Drawing.BufferSurface ((int)this.width, (int)this.height);

            /*
            * copied from popover-granite-drawing
            * https://code.launchpad.net/~tombeckmann/wingpanel/popover-granite-drawing
            */

            buffer.context.clip ();
            buffer.context.reset_clip ();

            // draw rect
            cairo_set_source_color (buffer.context, back_color);
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

        public void resize (int width, int height)
        {
            set_size (width, height);
            canvas.set_size (width, height);
            canvas.invalidate ();
        }
    }
}
