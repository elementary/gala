//
//  Copyright (C) 2019 Adam Bieńkowski
//                2020 Felix Andreas
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
    public class WindowMovementTracker : Object {
        public signal void position_changed (Meta.Window window);

        public weak WindowManager wm { get; construct; }
        private weak Meta.Display display;
        private Meta.Window current_window;

        public WindowMovementTracker (WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            display = wm.get_display ();
        }

        public void watch () {
            display.grab_op_begin.connect (on_grab_op_begin);
            display.grab_op_end.connect (on_grab_op_end);
        }

        public void unwatch () {
            display.grab_op_begin.disconnect (on_grab_op_begin);
            display.grab_op_end.disconnect (on_grab_op_end);
            current_window.position_changed.disconnect (on_position_changed);
        }

        private void on_grab_op_begin (Meta.Display display, Meta.Window? window, Meta.GrabOp op) {
            current_window = window;
            if (op == Meta.GrabOp.MOVING && current_window != null) {
                current_window.position_changed.connect (on_position_changed);
                on_position_changed (current_window);
            }
        }

        private void on_grab_op_end (Meta.Display display, Meta.Window? window, Meta.GrabOp op) {
            if (op == Meta.GrabOp.MOVING && current_window != null) {
                current_window.position_changed.disconnect (on_position_changed);
            }
        }

        private void on_position_changed (Meta.Window window) {
            position_changed (window);
        }
    }
}
