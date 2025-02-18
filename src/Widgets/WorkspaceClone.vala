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
            Object (
                display: display,
                monitor_index: display.get_primary_monitor (),
                control_position: false,
                rounded_corners: true
            );
        }

        construct {
#if HAS_MUTTER47
            unowned var ctx = context.get_backend ().get_cogl_context ();
#else
            unowned var ctx = Clutter.get_default_backend ().get_cogl_context ();
#endif
            pipeline = new Cogl.Pipeline (ctx);
            var primary = display.get_primary_monitor ();
            var monitor_geom = display.get_monitor_geometry (primary);

            var effect = new ShadowEffect ("workspace");
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
            Drawing.Utilities.cairo_rounded_rectangle (ctx, 0, 0, width, height, 9);
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

            var color = Cogl.Color.from_4f (1.0f, 1.0f, 1.0f, 25.0f / 255.0f);
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

        public WorkspaceClone (Meta.Workspace workspace, GestureTracker gesture_tracker, float scale) {
            Object (workspace: workspace, gesture_tracker: gesture_tracker, scale_factor: scale);
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

            window_container = new WindowCloneContainer (display, gesture_tracker, scale_factor) {
                width = monitor_geometry.width,
                height = monitor_geometry.height,
            };
            window_container.window_selected.connect ((w) => { window_selected (w); });
            window_container.requested_close.connect (() => selected (true));

            icon_group = new IconGroup (display, workspace, scale_factor);
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
                    && window.is_on_primary_monitor ()) {
                    window_container.add_window (window);
                    icon_group.add_window (window, true);
                }
            }

            var listener = WindowListener.get_default ();
            listener.window_no_longer_on_all_workspaces.connect (add_window);

            parent_set.connect ((old_parent) => {
                if (old_parent != null) {
                    old_parent.notify["x"].disconnect (update_icon_group_opacity);
                }

                get_parent ().notify["x"].connect (update_icon_group_opacity);
            });
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
            window_container.destroy ();
            icon_group.destroy ();
        }

        private void update_icon_group_opacity () {
            var offset = (multitasking_view_x () + get_parent ().x).abs ();

            var adjusted_width = width - InternalUtils.scale_to_int (X_OFFSET, scale_factor);

            icon_group.backdrop_opacity = (1 - (offset / adjusted_width)).clamp (0, 1);
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
                || !window.is_on_primary_monitor ())
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

#if HAS_MUTTER45
        public void update_size (Mtk.Rectangle monitor_geometry) {
#else
        public void update_size (Meta.Rectangle monitor_geometry) {
#endif
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
#if HAS_MUTTER45
        private static inline void shrink_rectangle (ref Mtk.Rectangle rect, int amount) {
#else
        private static inline void shrink_rectangle (ref Meta.Rectangle rect, int amount) {
#endif
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
            background.set_pivot_point (0.5f, pivot_y);

            update_size (monitor);

            new GesturePropertyTransition (this, gesture_tracker, "x", initial_x, target_x).start (with_gesture);
            new GesturePropertyTransition (background, gesture_tracker, "scale-x", null, (double) scale).start (with_gesture);
            new GesturePropertyTransition (background, gesture_tracker, "scale-y", null, (double) scale).start (with_gesture);

#if HAS_MUTTER45
            Mtk.Rectangle area = {
#else
            Meta.Rectangle area = {
#endif
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

            new GesturePropertyTransition (this, gesture_tracker, "x", initial_x, target_x).start (with_gesture);
            new GesturePropertyTransition (background, gesture_tracker, "scale-x", null, 1.0d).start (with_gesture);
            new GesturePropertyTransition (background, gesture_tracker, "scale-y", null, 1.0d).start (with_gesture);

            window_container.close (with_gesture);
        }
    }
}
