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
     * Utility class which adds a border and a shadow to a Background
     */
    private class FramedBackground : BackgroundManager {
        private Cogl.Pipeline pipeline;
        private Cairo.ImageSurface cached_surface;
        private Cairo.Context cached_context;
        private Cogl.Texture2D cached_texture;
        private int last_width;
        private int last_height;

        public FramedBackground (Meta.Display display) {
            Object (display: display, monitor_index: display.get_primary_monitor (), control_position: false);
        }

        construct {
            pipeline = new Cogl.Pipeline (Clutter.get_default_backend ().get_cogl_context ());
            var primary = display.get_primary_monitor ();
            var monitor_geom = display.get_monitor_geometry (primary);

            var effect = new ShadowEffect (40) {
                css_class = "workspace"
            };
            add_effect (effect);

            reactive = true;
        }

        public override void paint (Clutter.PaintContext context) {
            base.paint (context);

            if (cached_surface == null || last_width != (int) width || last_height != (int) height) {
                cached_texture = null;

                cached_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, (int) width, (int) height);
                cached_context = new Cairo.Context (cached_surface);
                last_width = (int) width;
                last_height = (int) height;
            }

            var surface = cached_surface;
            var ctx = cached_context;

            ctx.set_source_rgba (255, 255, 255, 255);
            ctx.rectangle (0, 0, (int) width, (int) height);
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.stroke ();
            ctx.restore ();
            ctx.paint ();

            try {
                if (cached_texture == null) {
                    var texture = new Cogl.Texture2D.from_data (
                        context.get_framebuffer ().get_context (),
                        (int) width, (int) height,
                        Cogl.PixelFormat.BGRA_8888_PRE,
                        surface.get_stride (), surface.get_data ()
                    );

                    pipeline.set_layer_texture (0, texture);
                    cached_texture = texture;
                }
            } catch (Error e) {
                debug (e.message);
            }

            var color = Cogl.Color.from_4ub (255, 255, 255, 25);
            color.premultiply ();

            pipeline.set_color (color);

            unowned var fb = context.get_framebuffer ();
            fb.draw_rectangle (pipeline, 0, 0, width, height);
        }
    }

    /**
     * This is the container which manages a clone of the background which will
     * be scaled and animated inwards, a WindowCloneContainer for the windows on
     * this workspace and also holds the instance for this workspace's IconGroup.
     * The latter is not added to the WorkspaceClone itself though but to a container
     * of the MultitaskingView.
     */
    public class WorkspaceClone : Clutter.Actor {
        /**
         * The offset of the scaled background to the bottom of the monitor bounds
         */
        public const int BOTTOM_OFFSET = 100;

        /**
         * The offset of the scaled background to the top of the monitor bounds
         */
        private const int TOP_OFFSET = 20;

        /**
         * The amount of time a window has to be over the WorkspaceClone while in drag
         * before we activate the workspace.
         */
        private const int HOVER_ACTIVATE_DELAY = 400;

        /**
         * The MultitaskingView shows the workspaces overlapping them WorkspaceClone.X_OFFSET pixels
         * making it possible to move windows to the next/previous workspace.
         */
        public const int X_OFFSET = 150;

        /**
         * A window has been selected, the MultitaskingView should consider activating
         * and closing the view.
         */
        public signal void window_selected (Meta.Window window);

        /**
         * The background has been selected. Switch to that workspace.
         *
         * @param close_view If the MultitaskingView should also consider closing itself
         *                   after switching.
         */
        public signal void selected (bool close_view);

        public WindowManager wm { get; construct; }
        public Meta.Workspace workspace { get; construct; }
        public GestureTracker gesture_tracker { get; construct; }
        public IconGroup icon_group { get; private set; }
        public WindowCloneContainer window_container { get; private set; }

        private float _scale_factor = 1.0f;
        public float scale_factor {
            get {
                return _scale_factor;
            }
            set {
                if (value != _scale_factor) {
                    _scale_factor = value;
                    reallocate ();
                }
            }
        }

        private BackgroundManager background;
        private bool opened;

        private uint hover_activate_timeout = 0;

        public WorkspaceClone (WindowManager wm, Meta.Workspace workspace, GestureTracker gesture_tracker, float scale) {
            Object (wm: wm, workspace: workspace, gesture_tracker: gesture_tracker, scale_factor: scale);
        }

        construct {
            opened = false;

            unowned Meta.Display display = workspace.get_display ();
            var primary_monitor = display.get_primary_monitor ();
            var monitor_geometry = display.get_monitor_geometry (primary_monitor);

            var background_click_action = new Clutter.ClickAction ();
            background_click_action.clicked.connect (() => {
                selected (true);
            });
            background = new FramedBackground (display);
            background.add_action (background_click_action);

            window_container = new WindowCloneContainer (wm, gesture_tracker, scale_factor);
            window_container.window_selected.connect ((w) => { window_selected (w); });
            window_container.set_size (monitor_geometry.width, monitor_geometry.height);

            icon_group = new IconGroup (wm, workspace, scale_factor);
            icon_group.selected.connect (() => selected (true));

            var icons_drop_action = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
            icon_group.add_action (icons_drop_action);

            var background_drop_action = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
            background.add_action (background_drop_action);
            background_drop_action.crossed.connect ((target, hovered) => {
                if (!hovered && hover_activate_timeout != 0) {
                    Source.remove (hover_activate_timeout);
                    hover_activate_timeout = 0;
                    return;
                }

                if (hovered && hover_activate_timeout == 0) {
                    hover_activate_timeout = Timeout.add (HOVER_ACTIVATE_DELAY, () => {
                        selected (false);
                        hover_activate_timeout = 0;
                        return false;
                    });
                }
            });

            display.window_entered_monitor.connect (window_entered_monitor);
            display.window_left_monitor.connect (window_left_monitor);
            workspace.window_added.connect (add_window);
            workspace.window_removed.connect (remove_window);

            add_child (background);
            add_child (window_container);

            // add existing windows
            var windows = workspace.list_windows ();
            foreach (var window in windows) {
                if (window.window_type == Meta.WindowType.NORMAL
                    && !window.on_all_workspaces
                    && window.get_monitor () == display.get_primary_monitor ()) {
                    window_container.add_window (window);
                    icon_group.add_window (window, true);
                }
            }

            var listener = WindowListener.get_default ();
            listener.window_no_longer_on_all_workspaces.connect (add_window);
        }

        ~WorkspaceClone () {
            unowned Meta.Display display = workspace.get_display ();

            display.window_entered_monitor.disconnect (window_entered_monitor);
            display.window_left_monitor.disconnect (window_left_monitor);
            workspace.window_added.disconnect (add_window);
            workspace.window_removed.disconnect (remove_window);

            var listener = WindowListener.get_default ();
            listener.window_no_longer_on_all_workspaces.disconnect (add_window);

            background.destroy ();
        }

        private void reallocate () {
            icon_group.scale_factor = scale_factor;
            window_container.monitor_scale = scale_factor;
        }

        /**
         * Add a window to the WindowCloneContainer and the IconGroup if it really
         * belongs to this workspace and this monitor.
         */
        private void add_window (Meta.Window window) {
            if (window.window_type != Meta.WindowType.NORMAL
                || window.get_workspace () != workspace
                || window.on_all_workspaces
                || window.get_monitor () != window.get_display ().get_primary_monitor ())
                return;

            foreach (var child in window_container.get_children ())
                if (((WindowClone) child).window == window)
                    return;

            window_container.add_window (window);
            icon_group.add_window (window);
        }

        /**
         * Remove a window from the WindowCloneContainer and the IconGroup
         */
        private void remove_window (Meta.Window window) {
            window_container.remove_window (window);
            icon_group.remove_window (window, opened);
        }

        private void window_entered_monitor (Meta.Display display, int monitor, Meta.Window window) {
            add_window (window);
        }

        private void window_left_monitor (Meta.Display display, int monitor, Meta.Window window) {
            if (monitor == display.get_primary_monitor ())
                remove_window (window);
        }

        public void update_size (Meta.Rectangle monitor_geometry) {
            if (window_container.width != monitor_geometry.width || window_container.height != monitor_geometry.height) {
                window_container.set_size (monitor_geometry.width, monitor_geometry.height);
                background.set_size (window_container.width, window_container.height);
            }
        }

        /**
         * @return The position on the X axis of this workspace.
         */
        public float multitasking_view_x () {
            return workspace.index () * (width - InternalUtils.scale_to_int (X_OFFSET, scale_factor));
        }

        /**
         * @return The amount of pixels the workspace is overlapped in the X axis.
         */
        private float current_x_overlap () {
            var display = workspace.get_display ();
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var active_index = manager.get_active_workspace ().index ();
            if (workspace.index () == active_index) {
                return 0;
            } else {
                var x_offset = InternalUtils.scale_to_int (X_OFFSET, scale_factor) + WindowManagerGala.WORKSPACE_GAP;
                return (workspace.index () < active_index) ? -x_offset : x_offset;
            }
        }

        /**
         * Utility function to shrink a MetaRectangle on all sides for the given amount.
         * Negative amounts will scale it instead.
         *
         * @param amount The amount in px to shrink.
         */
        private static inline void shrink_rectangle (ref Meta.Rectangle rect, int amount) {
            rect.x += amount;
            rect.y += amount;
            rect.width -= amount * 2;
            rect.height -= amount * 2;
        }

        /**
         * Animates the background to its scale, causes a redraw on the IconGroup and
         * makes sure the WindowCloneContainer animates its windows to their tiled layout.
         * Also sets the current_window of the WindowCloneContainer to the active window
         * if it belongs to this workspace.
         */
        public void open (bool with_gesture = false, bool is_cancel_animation = false) {
            if (opened) {
                return;
            }

            opened = true;

            window_container.restack_windows ();

            unowned var display = workspace.get_display ();

            var monitor = display.get_monitor_geometry (display.get_primary_monitor ());
            var initial_x = is_cancel_animation ? x : x + current_x_overlap ();
            var target_x = multitasking_view_x ();

            var scale = (float)(monitor.height - InternalUtils.scale_to_int (TOP_OFFSET + BOTTOM_OFFSET, scale_factor)) / monitor.height;
            var pivot_y = InternalUtils.scale_to_int (TOP_OFFSET, scale_factor) / (monitor.height - monitor.height * scale);

            update_size (monitor);

            GestureTracker.OnBegin on_animation_begin = () => {
                x = initial_x;
                background.set_pivot_point (0.5f, pivot_y);
            };

            GestureTracker.OnUpdate on_animation_update = (percentage) => {
                var x = GestureTracker.animation_value (initial_x, target_x, percentage);
                set_x (x);

                var update_scale = (double) GestureTracker.animation_value (1.0f, (float)scale, percentage);
                background.set_scale (update_scale, update_scale);
            };

            GestureTracker.OnEnd on_animation_end = (percentage, cancel_action) => {
                if (cancel_action) {
                    return;
                }

                save_easing_state ();
                set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
                set_easing_duration (wm.enable_animations ? MultitaskingView.ANIMATION_DURATION : 0);
                set_x (target_x);
                restore_easing_state ();

                background.save_easing_state ();
                background.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
                background.set_easing_duration (wm.enable_animations ? MultitaskingView.ANIMATION_DURATION : 0);
                background.set_scale (scale, scale);
                background.restore_easing_state ();
            };

            if (!with_gesture || !wm.enable_animations) {
                on_animation_begin (0);
                on_animation_end (1, false, 0);
            } else {
                gesture_tracker.connect_handlers ((owned) on_animation_begin, (owned) on_animation_update, (owned)on_animation_end);
            }

            Meta.Rectangle area = {
                (int)Math.floorf (monitor.x + monitor.width - monitor.width * scale) / 2,
                (int)Math.floorf (monitor.y + InternalUtils.scale_to_int (TOP_OFFSET, scale_factor)),
                (int)Math.floorf (monitor.width * scale),
                (int)Math.floorf (monitor.height * scale)
            };
            shrink_rectangle (ref area, 32);

            window_container.padding_top = InternalUtils.scale_to_int (TOP_OFFSET, scale_factor);
            window_container.padding_left =
                window_container.padding_right = (int)(monitor.width - monitor.width * scale) / 2;
            window_container.padding_bottom = InternalUtils.scale_to_int (BOTTOM_OFFSET, scale_factor);

            icon_group.redraw ();

            Meta.Window? selected_window = display.get_workspace_manager ().get_active_workspace () == workspace ? display.get_focus_window () : null;
            window_container.open (selected_window, with_gesture, is_cancel_animation);
        }

        /**
         * Close the view again by animating the background back to its scale and
         * the windows back to their old locations.
         */
        public void close (bool with_gesture = false, bool is_cancel_animation = false) {
            if (!opened) {
                return;
            }

            opened = false;

            window_container.restack_windows ();

            var initial_x = is_cancel_animation ? x : multitasking_view_x ();
            var target_x = multitasking_view_x () + current_x_overlap ();

            double initial_scale_x, initial_scale_y;
            background.get_scale (out initial_scale_x, out initial_scale_y);

            GestureTracker.OnUpdate on_animation_update = (percentage) => {
                var x = GestureTracker.animation_value (initial_x, target_x, percentage);
                set_x (x);

                double scale_x = (double) GestureTracker.animation_value ((float) initial_scale_x, 1.0f, percentage);
                double scale_y = (double) GestureTracker.animation_value ((float) initial_scale_y, 1.0f, percentage);
                background.set_scale (scale_x, scale_y);
            };

            GestureTracker.OnEnd on_animation_end = (percentage, cancel_action) => {
                if (cancel_action) {
                    return;
                }

                save_easing_state ();
                set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
                set_easing_duration (wm.enable_animations ? MultitaskingView.ANIMATION_DURATION : 0);
                set_x (target_x);
                restore_easing_state ();

                background.save_easing_state ();
                background.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
                background.set_easing_duration (wm.enable_animations ? MultitaskingView.ANIMATION_DURATION : 0);
                background.set_scale (1, 1);
                background.restore_easing_state ();
            };

            if (!with_gesture || !wm.enable_animations) {
                on_animation_end (1, false, 0);
            } else {
                gesture_tracker.connect_handlers (null, (owned) on_animation_update, (owned) on_animation_end);
            }

            window_container.close (with_gesture, is_cancel_animation);
        }
    }
}
