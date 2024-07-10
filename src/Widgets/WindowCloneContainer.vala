//
//  Copyright (C) 2014 Tom Beckmann
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
    /**
     * Container which controls the layout of a set of WindowClones.
     */
    public class WindowCloneContainer : Clutter.Actor {
        public signal void window_selected (Meta.Window window);
        public signal void requested_close ();

        public int padding_top { get; set; default = 12; }
        public int padding_left { get; set; default = 12; }
        public int padding_right { get; set; default = 12; }
        public int padding_bottom { get; set; default = 12; }

        public WindowManager wm { get; construct; }
        public GestureTracker? gesture_tracker { get; construct; }
        public bool overview_mode { get; construct; }

        private float _monitor_scale = 1.0f;
        public float monitor_scale {
            get {
                return _monitor_scale;
            }
            set {
                if (value != _monitor_scale) {
                    _monitor_scale = value;
                    reallocate ();
                }
            }
        }

        private bool opened = false;

        /**
         * The window that is currently selected via keyboard shortcuts. It is not
         * necessarily the same as the active window.
         */
        private WindowClone? current_window = null;

        public WindowCloneContainer (WindowManager wm, GestureTracker? gesture_tracker, float scale, bool overview_mode = false) {
            Object (wm: wm, gesture_tracker: gesture_tracker, monitor_scale: scale, overview_mode: overview_mode);
        }

        private void reallocate () {
            foreach (unowned var child in get_children ()) {
                unowned var clone = (WindowClone) child;
                clone.monitor_scale_factor = monitor_scale;
            }
        }

        /**
         * Create a WindowClone for a MetaWindow and add it to the group
         *
         * @param window The window for which to create the WindowClone for
         */
        public void add_window (Meta.Window window) {
            unowned Meta.Display display = window.get_display ();

            var windows = new List<Meta.Window> ();
            foreach (unowned var child in get_children ()) {
                unowned var clone = (WindowClone) child;
                windows.append (clone.window);
            }
            windows.append (window);

            var windows_ordered = InternalUtils.sort_windows (display, windows);

            var new_window = new WindowClone (wm, window, gesture_tracker, monitor_scale, overview_mode);

            new_window.selected.connect ((clone) => window_selected (clone.window));
            new_window.destroy.connect ((_new_window) => {
                // make sure to release reference if the window is selected
                if (_new_window == current_window) {
                    select_next_window (Meta.MotionDirection.RIGHT);
                }

                // if window is still selected, reset the selection
                if (_new_window == current_window) {
                    current_window = null;
                }

                reflow ();
            });
            new_window.request_reposition.connect (() => reflow ());

            unowned Meta.Window? target = null;
            foreach (unowned var w in windows_ordered) {
                if (w != window) {
                    target = w;
                    continue;
                }
                break;
            }

            // top most or no other children
            if (target == null) {
                add_child (new_window);
            }

            foreach (unowned var child in get_children ()) {
                unowned var clone = (WindowClone) child;
                if (target == clone.window) {
                    insert_child_below (new_window, clone);
                    break;
                }
            }

            reflow ();
        }

        /**
         * Find and remove the WindowClone for a MetaWindow
         */
        public void remove_window (Meta.Window window) {
            foreach (unowned var child in get_children ()) {
                if (((WindowClone) child).window == window) {
                    remove_child (child);
                    reflow ();
                    break;
                }
            }
        }

        /**
         * Sort the windows z-order by their actual stacking to make intersections
         * during animations correct.
         */
        public void restack_windows () {
            var children = get_children ();

            var windows = new List<Meta.Window> ();
            foreach (unowned Clutter.Actor child in children) {
                windows.prepend (((WindowClone) child).window);
            }

            var windows_ordered = InternalUtils.sort_windows (wm.get_display (), windows);
            windows_ordered.reverse ();

            var i = 0;
            foreach (unowned var window in windows_ordered) {
                foreach (unowned var child in children) {
                    if (((WindowClone) child).window == window) {
                        set_child_at_index (child, i);
                        children.remove (child);
                        i++;
                        break;
                    }
                }
            }
        }

        /**
         * Recalculate the tiling positions of the windows and animate them to
         * the resulting spots.
         */
        public void reflow (bool with_gesture = false, bool is_cancel_animation = false) {
            if (!opened) {
                return;
            }

            var windows = new List<InternalUtils.TilableWindow?> ();
            foreach (unowned var child in get_children ()) {
                unowned var clone = (WindowClone) child;
                windows.prepend ({ clone.window.get_frame_rect (), clone });
            }

            if (windows.is_empty ()) {
                return;
            }

            // make sure the windows are always in the same order so the algorithm
            // doesn't give us different slots based on stacking order, which can lead
            // to windows flying around weirdly
            windows.sort ((a, b) => {
                var seq_a = ((WindowClone) a.id).window.get_stable_sequence ();
                var seq_b = ((WindowClone) b.id).window.get_stable_sequence ();
                return (int) (seq_b - seq_a);
            });

#if HAS_MUTTER45
            Mtk.Rectangle area = {
#else
            Meta.Rectangle area = {
#endif
                padding_left,
                padding_top,
                (int)width - padding_left - padding_right,
                (int)height - padding_top - padding_bottom
            };

            var window_positions = InternalUtils.calculate_grid_placement (area, windows);

            foreach (var tilable in window_positions) {
                unowned var clone = (WindowClone) tilable.id;
                clone.take_slot (tilable.rect, with_gesture, is_cancel_animation);
            }
        }

        /**
         * Collect key events, mainly for redirecting them to the WindowCloneContainers to
         * select the active window.
         */
#if HAS_MUTTER45
        public override bool key_press_event (Clutter.Event event) {
#else
        public override bool key_press_event (Clutter.KeyEvent event) {
#endif
            if (!opened) {
                return Clutter.EVENT_PROPAGATE;
            }

            switch (event.get_key_symbol ()) {
                case Clutter.Key.Escape:
                    requested_close ();
                    break;
                case Clutter.Key.Down:
                    select_next_window (Meta.MotionDirection.DOWN);
                    break;
                case Clutter.Key.Up:
                    select_next_window (Meta.MotionDirection.UP);
                    break;
                case Clutter.Key.Left:
                    select_next_window (Meta.MotionDirection.LEFT);
                    break;
                case Clutter.Key.Right:
                    select_next_window (Meta.MotionDirection.RIGHT);
                    break;
                case Clutter.Key.Return:
                case Clutter.Key.KP_Enter:
                    if (!activate_selected_window ()) {
                        requested_close ();
                    }
                    break;
            }

            return Clutter.EVENT_STOP;
        }

        /**
         * Look for the next window in a direction and make this window the
         * new current_window. Used for keyboard navigation.
         *
         * @param direction The MetaMotionDirection in which to search for windows for.
         */
        public void select_next_window (Meta.MotionDirection direction) {
            if (get_n_children () < 1) {
                return;
            }

            WindowClone? closest = null;

            if (current_window == null) {
                closest = (WindowClone) get_child_at_index (0);
            } else {
                var current_rect = current_window.slot;

                foreach (unowned var child in get_children ()) {
                    if (child == current_window) {
                        continue;
                    }

                    var window_rect = ((WindowClone) child).slot;

                    if (direction == LEFT) {
                        if (window_rect.x > current_rect.x) {
                            continue;
                        }

                        // test for vertical intersection
                        if (window_rect.y + window_rect.height > current_rect.y
                            && window_rect.y < current_rect.y + current_rect.height) {

                            if (closest == null || closest.slot.x < window_rect.x) {
                                closest = (WindowClone) child;
                            }
                        }
                    } else if (direction == RIGHT) {
                        if (window_rect.x < current_rect.x) {
                            continue;
                        }

                        // test for vertical intersection
                        if (window_rect.y + window_rect.height > current_rect.y
                            && window_rect.y < current_rect.y + current_rect.height) {

                            if (closest == null || closest.slot.x > window_rect.x) {
                                closest = (WindowClone) child;
                            }
                        }
                    } else if (direction == UP) {
                        if (window_rect.y > current_rect.y) {
                            continue;
                        }

                        // test for horizontal intersection
                        if (window_rect.x + window_rect.width > current_rect.x
                            && window_rect.x < current_rect.x + current_rect.width) {

                            if (closest == null || closest.slot.y < window_rect.y) {
                                closest = (WindowClone) child;
                            }
                        }
                    } else if (direction == DOWN) {
                        if (window_rect.y < current_rect.y) {
                            continue;
                        }

                        // test for horizontal intersection
                        if (window_rect.x + window_rect.width > current_rect.x
                            && window_rect.x < current_rect.x + current_rect.width) {

                            if (closest == null || closest.slot.y > window_rect.y) {
                                closest = (WindowClone) child;
                            }
                        }
                    } else {
                        warning ("Invalid direction");
                        break;
                    }
                }
            }

            if (closest == null) {
                if (current_window != null) {
                    Clutter.get_default_backend ().get_default_seat ().bell_notify ();
                    current_window.active = true;
                }
                return;
            }

            if (current_window != null) {
                current_window.active = false;
            }

            closest.active = true;
            current_window = closest;
        }

        /**
         * Emit the selected signal for the current_window.
         */
        public bool activate_selected_window () {
            if (current_window != null) {
                window_selected (current_window.window);
                return true;
            }

            return false;
        }

        /**
         * When opened the WindowClones are animated to a tiled layout
         */
        public void open (Meta.Window? selected_window, bool with_gesture, bool is_cancel_animation) {
            if (opened) {
                return;
            }

            opened = true;

            // hide the highlight when opened
            if (selected_window != null) {
                foreach (var child in get_children ()) {
                    unowned var clone = (WindowClone) child;
                    if (clone.window == selected_window) {
                        current_window = clone;
                        break;
                    }
                }

                if (current_window != null) {
                    current_window.active = false;
                }
            } else {
                current_window = null;
            }

            // make sure our windows are where they belong in case they were moved
            // while were closed.
            if (gesture_tracker == null || !is_cancel_animation) {
                foreach (var window in get_children ()) {
                    ((WindowClone) window).transition_to_original_state (false, with_gesture, is_cancel_animation);
                }
            }

            reflow (with_gesture, is_cancel_animation);
        }

        /**
         * Calls the transition_to_original_state() function on each child
         * to make them take their original locations again.
         */
        public void close (bool with_gesture = false, bool is_cancel_animation = false) {
            if (!opened) {
                return;
            }

            opened = false;

            foreach (var window in get_children ()) {
                ((WindowClone) window).transition_to_original_state (true, with_gesture, is_cancel_animation);
            }
        }
    }
}
