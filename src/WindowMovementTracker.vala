//
//  Copyright (C) 2019 Adam Bieńkowski
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

namespace Gala
{
    public class WindowMovementTracker : Object {
        public weak Meta.Display display { get; construct; }
        public signal void open (Meta.Window window, int x, int y);
        private Meta.Window? current_window;
        private const float TRIGGER_RATIO = 0.98f;

        private float start_x;
        private float start_y;
        private Meta.MaximizeFlags maximize_flags;

        public WindowMovementTracker (Meta.Display display) {
            Object (display: display);
        }

        public void watch () {
            display.grab_op_begin.connect (on_grab_op_begin);
            display.grab_op_end.connect (on_grab_op_end);
        }

        public void unwatch ()  {
            display.grab_op_begin.disconnect (on_grab_op_begin);
            display.grab_op_end.disconnect (on_grab_op_end); 
            
            if (current_window != null) {
                current_window.position_changed.disconnect (on_position_changed);
            }
        }

        public void restore_window_state () {
            var actor = (Meta.WindowActor)current_window.get_compositor_private ();
            current_window.move_frame (false, (int)start_x, (int)start_y);
            if (maximize_flags != 0) {
                current_window.maximize (maximize_flags);

                /**
                 * kill_window_effects does not reset the translation
                 * and that's the only thing we want to do
                 */
                actor.set_translation (0.0f, 0.0f, 0.0f);
            }
        }

        private void on_grab_op_begin (Meta.Screen screen, Meta.Window? window, Meta.GrabOp op) {
            if (window == null) {
                return;
            }

            current_window = window;

            var actor = (Meta.WindowActor)window.get_compositor_private ();
            start_x = actor.x;
            start_y = actor.y;
            maximize_flags = window.get_maximized ();

            current_window.position_changed.connect (on_position_changed);
        }

        private void on_grab_op_end (Meta.Screen screen, Meta.Window? window, Meta.GrabOp op) {
            current_window.position_changed.disconnect (on_position_changed);
        }

        private void on_position_changed (Meta.Window window) {
            unowned Meta.Screen screen = window.get_screen ();
            unowned Meta.CursorTracker ct = screen.get_cursor_tracker ();
            int x, y;
            Clutter.ModifierType type;
            ct.get_pointer (out x, out y, out type);

            int height;
            screen.get_size (null, out height);

            Meta.Rectangle wa = window.get_work_area_for_monitor (screen.get_current_monitor ());
            if (y - wa.y > wa.height * TRIGGER_RATIO && !has_monitor_below (window)) {
                window.position_changed.disconnect (on_position_changed);
                open (window, x, y);
            }
        }

        private static bool has_monitor_below (Meta.Window window) {
            unowned Meta.Screen screen = window.get_screen ();
            var current_monitor = screen.get_current_monitor ();
            
            var current_rect = window.get_work_area_for_monitor (current_monitor);
            var current_end_x = current_rect.x + current_rect.width - 1;
            var current_end_y = current_rect.y + current_rect.height - 1;
            for (int i = 0; i < screen.get_n_monitors (); i++) {
                if (i == current_monitor) {
                    continue;
                }

                var other_rect = window.get_work_area_for_monitor (i);
                if (current_end_y < other_rect.y) {
                    if (current_rect.x <= other_rect.x + other_rect.width - 1 && current_end_x >= other_rect.x) {
                        return true;
                    }
                }
            }

            return false;
        }
    }
}
