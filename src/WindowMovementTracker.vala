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
        public weak Meta.Display display { get; construct; }
        public AreaTiling area_tiling { get; construct; }
        private Meta.Window current_window;

        public WindowMovementTracker (Meta.Display display, AreaTiling area_tiling) {
            Object (display: display, area_tiling: area_tiling);
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

        private void on_grab_op_begin (Meta.Display display, Meta.Window window) {
            current_window = window;
            current_window.position_changed.connect (on_position_changed);
        }

        private void on_grab_op_end (Meta.Display display, Meta.Window window) {
            current_window.position_changed.disconnect (on_position_changed);
            if (area_tiling.is_active) {
                unowned Meta.CursorTracker ct = display.get_cursor_tracker ();
                int x, y;
                ct.get_pointer (out x, out y, null);
                area_tiling.tile (window, x, y);
                area_tiling.hide_preview (window);
            }
        }

        private void on_position_changed (Meta.Window window) {
            int x, y;
            Clutter.ModifierType type;
            display.get_cursor_tracker ().get_pointer (out x, out y, out type);

            if ((type & Gdk.ModifierType.CONTROL_MASK) != 0) {
                area_tiling.show_preview (window, x, y);
            } else if (area_tiling.is_active) {
                area_tiling.hide_preview (window);
            }
        }
    }
}
