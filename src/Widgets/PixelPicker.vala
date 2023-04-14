//
//  Copyright (C) 2020 elementary, Inc. (https://elementary.io)
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
    public class PixelPicker : Clutter.Actor {
        public signal void closed ();

        public WindowManager wm { get; construct; }
        public bool cancelled { get; private set; }
        public Graphene.Point point { get; private set; }

        private ModalProxy? modal_proxy;

        public PixelPicker (WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            point.init (0, 0);
            visible = true;
            reactive = true;

            int screen_width, screen_height;
            wm.get_display ().get_size (out screen_width, out screen_height);
            width = screen_width;
            height = screen_height;

            var canvas = new Clutter.Canvas ();
            canvas.set_size (screen_width, screen_height);
            set_content (canvas);
        }

        public override bool key_press_event (Clutter.KeyEvent e) {
            if (e.keyval == Clutter.Key.Escape) {
                close ();
                cancelled = true;
                closed ();
                return true;
            }

            return false;
        }

        public override bool button_release_event (Clutter.ButtonEvent e) {
            if (e.button != 1) {
                return true;
            }

            point = Graphene.Point () { x = e.x, y = e.y };

            close ();
            this.hide ();
            content.invalidate ();

            closed ();
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
    }
}
