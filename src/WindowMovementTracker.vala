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

using Meta;

namespace Gala {
    public class WindowMovementTracker : Object {
        int animation_duration = 250;
        public weak Meta.Display display { get; construct; }
        public signal void show_tile_preview (Meta.Window window, Meta.Rectangle tile_rect, int tile_monitor_number);
        public signal void hide_tile_preview ();
        public bool hide_tile_preview_when_window_moves = true;
        private Meta.Window? current_window;
        private Meta.Rectangle tile_rect = new Meta.Rectangle ();

        Clutter.Actor window_icon;
        private float start_x;
        private float start_y;
        private bool is_shrinked = false;
        private Meta.MaximizeFlags maximize_flags;

        public WindowMovementTracker (Meta.Display display) {
            Object (display: display);
        }

        public void watch () {
            display.grab_op_begin.connect (on_grab_op_begin);
            display.grab_op_end.connect (on_grab_op_end);
        }

        public void unwatch () {
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
            if (!hide_tile_preview_when_window_moves) {
                window.move_resize_frame (true, tile_rect.x, tile_rect.y, tile_rect.width, tile_rect.height);
            }

            if (is_shrinked) {
                unshrink_window (window);
            }
            current_window.position_changed.disconnect (on_position_changed);
            hide_tile_preview_when_window_moves = true;
            hide_tile_preview ();
        }

        private void shrink_window (Meta.Window? window, float x, float y) {
            is_shrinked = true;
            debug("shrink window!");
            float abs_x, abs_y;
            var actor = (Meta.WindowActor)window.get_compositor_private ();
            actor.get_transformed_position (out abs_x, out abs_y);

            int width, height;
            window.get_screen ().get_size (out width, out height);
            actor.set_pivot_point ((x - abs_x) / actor.width, (y - abs_y) / actor.height);
            actor.save_easing_state ();
            actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_EXPO);
            actor.set_easing_duration (animation_duration);
            actor.set_scale (0.0f, 0.0f);
            actor.opacity = 0U;
            actor.restore_easing_state ();

            var scale_factor = InternalUtils.get_ui_scaling_factor ();
            window_icon = new WindowIcon (window, 64, scale_factor);
            window_icon.opacity = 255;
            window_icon.set_pivot_point (0.5f, 0.5f);
            var stage = actor.get_stage ();
            stage.add_child (window_icon);
        }

        private void unshrink_window (Meta.Window? window) {
            debug("unshrink window!");
            is_shrinked = false;
            var actor = (Meta.WindowActor)window.get_compositor_private ();

            int width, height;
            window.get_screen ().get_size (out width, out height);
            actor.set_pivot_point (0.5f, 1.0f);
            actor.set_scale (0.01f, 0.1f);
            actor.opacity = 0U;

            actor.save_easing_state ();
            actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_EXPO);
            actor.set_easing_duration (animation_duration);
            actor.set_scale (1.0f, 1.0f);
            actor.opacity = 255U;
            actor.restore_easing_state ();
            window_icon.opacity = 0;
        }

        private void on_position_changed (Meta.Window window) {
            unowned Meta.Screen screen = window.get_screen ();
            unowned Meta.CursorTracker ct = screen.get_cursor_tracker ();
            int x, y;
            Clutter.ModifierType type;
            ct.get_pointer (out x, out y, out type);

            if ((type & Gdk.ModifierType.CONTROL_MASK) != 0) {
                Meta.Rectangle wa = window.get_work_area_for_monitor (screen.get_current_monitor ());

                int monitor_width = wa.width, monitor_height = wa.height;
                int monitor_x = x - wa.x, monitor_y = y - wa.y;
                int new_width, new_height;
                int new_x = wa.x, new_y = wa.y;

                if (!is_shrinked){
                    shrink_window (window, (float) x, (float) y);
                } else {
                    window_icon.set_position((float) x - 48.0f, (float) y - 48.0f);
                }

                if (monitor_x < (float) monitor_width * 2 / 5) {
                    new_width = monitor_width / 2;
                } else if (monitor_x < (float) monitor_width * 3 / 5) {
                    new_width = monitor_width;
                } else {
                    new_width = monitor_width / 2;
                    new_x += monitor_width / 2;
                }

                if (monitor_y < (float) monitor_height * 2 / 5) {
                    new_height = monitor_height / 2;
                } else if (monitor_y < (float) monitor_height * 3 / 5) {
                    new_height = monitor_height;
                } else {
                    new_height = monitor_height / 2;
                    new_y += monitor_height / 2;
                }

                hide_tile_preview_when_window_moves = false;
                tile_rect = {new_x, new_y, new_width, new_height};
                show_tile_preview (window, tile_rect, screen.get_current_monitor ());
                return;
            }

            if (is_shrinked) {
                unshrink_window(window);
            }

            hide_tile_preview_when_window_moves = true;
        }
    }
}
