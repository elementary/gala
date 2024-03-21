//
//  Copyright (C) 2017 Santiago León O., Adam Bieńkowski
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
    public class SelectionArea : CanvasActor {
        public signal void closed ();

        public WindowManager wm { get; construct; }

        public bool cancelled { get; private set; }

        private ModalProxy? modal_proxy;
        private Graphene.Point start_point;
        private Graphene.Point end_point;
        private bool dragging = false;
        private bool clicked = false;

        public SelectionArea (WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            start_point.init (0, 0);
            end_point.init (0, 0);
            visible = true;
            reactive = true;

            int screen_width, screen_height;
            wm.get_display ().get_size (out screen_width, out screen_height);
            width = screen_width;
            height = screen_height;
        }

#if HAS_MUTTER45
        public override bool key_press_event (Clutter.Event e) {
#else
        public override bool key_press_event (Clutter.KeyEvent e) {
#endif
            if (e.get_key_symbol () == Clutter.Key.Escape) {
                close ();
                cancelled = true;
                closed ();
                return true;
            }

            return false;
        }

#if HAS_MUTTER45
        public override bool button_press_event (Clutter.Event e) {
#else
        public override bool button_press_event (Clutter.ButtonEvent e) {
#endif
            if (dragging || e.get_button () != Clutter.Button.PRIMARY) {
                return true;
            }

            clicked = true;

            float x, y;
            e.get_coords (out x, out y);
            start_point.init (x, y);

            return true;
        }

#if HAS_MUTTER45
        public override bool button_release_event (Clutter.Event e) {
#else
        public override bool button_release_event (Clutter.ButtonEvent e) {
#endif
            if (e.get_button () != Clutter.Button.PRIMARY) {
                return true;
            }

            if (!dragging) {
                close ();
                cancelled = true;
                closed ();
                return true;
            }

            dragging = false;
            clicked = false;

            close ();
            this.hide ();
            content.invalidate ();

            closed ();
            return true;
        }

#if HAS_MUTTER45
        public override bool motion_event (Clutter.Event e) {
#else
        public override bool motion_event (Clutter.MotionEvent e) {
#endif
            if (!clicked) {
                return true;
            }

            float x, y;
            e.get_coords (out x, out y);
            end_point.init (x, y);
            content.invalidate ();

            if (!dragging) {
                dragging = true;
            }

            return true;
        }

        public void close () {
            wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);

            if (modal_proxy != null) {
                wm.pop_modal (modal_proxy);
            }
        }

        public void start_selection () {
            wm.get_display ().set_cursor (Meta.Cursor.CROSSHAIR);
            grab_key_focus ();

            modal_proxy = wm.push_modal (this);
        }

        public Graphene.Rect get_selection_rectangle () {
            return Graphene.Rect () {
                origin = start_point,
                size = Graphene.Size.zero ()
            }.expand (end_point);
        }

        protected override void draw (Cairo.Context ctx, int width, int height) {
            ctx.save ();

            ctx.set_operator (Cairo.Operator.CLEAR);
            ctx.paint ();

            ctx.restore ();

            if (!dragging) {
                return;
            }

            ctx.translate (0.5, 0.5);

            var rect = get_selection_rectangle ();
            ctx.rectangle (rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
            ctx.set_source_rgba (0.1, 0.1, 0.1, 0.2);
            ctx.fill ();

            ctx.rectangle (rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
            ctx.set_source_rgb (0.7, 0.7, 0.7);
            ctx.set_line_width (1.0);
            ctx.stroke ();
        }
    }
}
