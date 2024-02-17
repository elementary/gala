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
        public override bool button_release_event (Clutter.Event e) {
#else
        public override bool button_release_event (Clutter.ButtonEvent e) {
#endif
            if (e.get_button () != Clutter.Button.PRIMARY) {
                return true;
            }

            float x, y;
            e.get_coords (out x, out y);
            point = Graphene.Point () { x = x, y = y };

            close ();
            this.hide ();

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
