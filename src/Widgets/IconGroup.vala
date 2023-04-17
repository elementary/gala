/*
 * Copyright 2014 Tom Beckmann
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    /**
     * Container for WindowIconActors which takes care of the scaling and positioning.
     * It also decides whether to draw the container shape, a plus sign or an ellipsis.
     * Lastly it also includes the drawing code for the active highlight.
     */
    public class IconGroup : Clutter.Actor {
        public const int SIZE = 64;

        private const int PLUS_SIZE = 8;
        private const int PLUS_WIDTH = 24;
        private const int BACKDROP_ABSOLUTE_OPACITY = 40;
        private const int CLOSE_BUTTON_SIZE = 36;
        private const int SHOW_CLOSE_BUTTON_DELAY = 200;

        /**
         * The group has been clicked. The MultitaskingView should consider activating
         * its workspace.
         */
        public signal void selected ();

        private float _backdrop_opacity = 0.0f;
        /**
         * The opacity of the backdrop/highlight.
         */
        public float backdrop_opacity {
            get {
                return _backdrop_opacity;
            }
            set {
                _backdrop_opacity = value;
                queue_redraw ();
            }
        }

        private DragDropAction drag_action;

        public WindowManager wm { get; construct; }
        public Meta.Workspace workspace { get; construct; }
        private float _scale_factor = 1.0f;
        public float scale_factor {
            get { return _scale_factor; }
            set {
                if (value != _scale_factor) {
                    _scale_factor = value;
                    resize_canvas ();
                    create_close_button ();
                }
            }
        }

        private Clutter.Actor? prev_parent = null;
        private Clutter.Actor close_button;
        private Clutter.Actor icon_container;

        public IconGroup (WindowManager wm, Meta.Workspace workspace, float scale) {
            Object (wm: wm, workspace: workspace, scale_factor: scale);
        }

        construct {
            reactive = true;

            var canvas = new Clutter.Canvas ();
            canvas.draw.connect (draw);
            content = canvas;

            drag_action = new DragDropAction (DragDropActionType.SOURCE | DragDropActionType.DESTINATION, "multitaskingview-window");
            drag_action.actor_clicked.connect (() => selected ());
            drag_action.drag_begin.connect (drag_begin);
            drag_action.drag_end.connect (drag_end);
            drag_action.drag_canceled.connect (drag_canceled);
            drag_action.notify["dragging"].connect (redraw);
            add_action (drag_action);

            icon_container = new Clutter.Actor ();
            icon_container.width = width;
            icon_container.height = height;

            add_child (icon_container);

            resize_canvas ();

            create_close_button ();

            icon_container.actor_removed.connect_after (redraw);
        }

        private void create_close_button () {
            close_button = Utils.create_close_button (scale_factor);
            place_close_button ();
            close_button.opacity = 0;
            close_button.reactive = true;
            close_button.visible = false;

            // block propagation of button presses on the close button, otherwise
            // the click action on the icon group will act weirdly
            close_button.button_release_event.connect (() => { return Clutter.EVENT_STOP; });

            add_child (close_button);

            var close_click = new Clutter.ClickAction ();
            close_click.clicked.connect (close);
            close_button.add_action (close_click);
        }

        ~IconGroup () {
            icon_container.actor_removed.disconnect (redraw);
        }

        public override bool enter_event (Clutter.CrossingEvent event) {
            toggle_close_button (true);

            return Clutter.EVENT_PROPAGATE;
        }

        public override bool leave_event (Clutter.CrossingEvent event) {
            if (!contains (event.related)) {
                toggle_close_button (false);
            }

            return Clutter.EVENT_PROPAGATE;
        }

        /**
         * Requests toggling the close button. If show is true, a timeout will be set after which
         * the close button is shown, if false, the close button is hidden and the timeout is removed,
         * if it exists. The close button may not be shown even though requested if the workspace has
         * no windows or workspaces aren't set to be dynamic.
         *
         * @param show Whether to show the close button
         */
        private void toggle_close_button (bool show) {
            // don't display the close button when we don't have dynamic workspaces
            // or when there are no windows on us. For one, our method for closing
            // wouldn't work anyway without windows and it's also the last workspace
            // which we don't want to have closed if everything went correct
            if (!Meta.Prefs.get_dynamic_workspaces () || icon_container.get_n_children () < 1 || drag_action.dragging) {
                return;
            }

            var old_transition = close_button.get_transition ("opacity");
            if (old_transition != null) {
                old_transition.stop ();
                close_button.remove_transition ("opacity");
            }

            close_button.visible = true;
            close_button.save_easing_state ();
            close_button.set_easing_mode (Clutter.AnimationMode.LINEAR);
            close_button.set_easing_duration (wm.enable_animations ? 200 : 0);
            close_button.set_easing_delay (show ? SHOW_CLOSE_BUTTON_DELAY : 0);
            close_button.opacity = show ? 255 : 0;
            close_button.restore_easing_state ();

            if (!show) {
                var transition = close_button.get_transition ("opacity");
                if (transition != null) {
                    transition.completed.connect (() => {
                        close_button.visible = false;
                    });
                } else {
                    close_button.visible = false;
                }
            }
        }

        private bool resize_canvas () {
            var size = InternalUtils.scale_to_int (SIZE, scale_factor);

            width = size;
            height = size;

            return ((Clutter.Canvas) content).set_size (size, size);
        }

        private void place_close_button () {
            var size = InternalUtils.scale_to_int (CLOSE_BUTTON_SIZE, scale_factor);
            close_button.set_size (size, size);

            close_button.x = -Math.floorf (close_button.width * 0.4f);
            close_button.y = -Math.floorf (close_button.height * 0.4f);
        }

        /**
         * Override the paint handler to draw our backdrop if necessary
         */
        public override void paint (Clutter.PaintContext context) {
            if (backdrop_opacity == 0.0 || drag_action.dragging) {
                base.paint (context);
                return;
            }

            var width = InternalUtils.scale_to_int (100, scale_factor);
            var x = (InternalUtils.scale_to_int (SIZE, scale_factor) - width) / 2;
            var y = -10;
            var height = InternalUtils.scale_to_int (WorkspaceClone.BOTTOM_OFFSET, scale_factor);
            var backdrop_opacity_int = (uint8) (BACKDROP_ABSOLUTE_OPACITY * backdrop_opacity);

            Cogl.VertexP2T2C4 vertices[4];
            vertices[0] = { x, y + height, 0, 1, backdrop_opacity_int, backdrop_opacity_int, backdrop_opacity_int, backdrop_opacity_int };
            vertices[1] = { x, y, 0, 0, 0, 0, 0, 0 };
            vertices[2] = { x + width, y + height, 1, 1, backdrop_opacity_int, backdrop_opacity_int, backdrop_opacity_int, backdrop_opacity_int };
            vertices[3] = { x + width, y, 1, 0, 0, 0, 0, 0 };

            var primitive = new Cogl.Primitive.p2t2c4 (context.get_framebuffer ().get_context (), Cogl.VerticesMode.TRIANGLE_STRIP, vertices);
            var pipeline = new Cogl.Pipeline (context.get_framebuffer ().get_context ());
            primitive.draw (context.get_framebuffer (), pipeline);
            base.paint (context);
        }

        /**
         * Remove all currently added WindowIconActors
         */
        public void clear () {
            icon_container.destroy_all_children ();
        }

        /**
         * Creates a WindowIconActor for the given window and adds it to the group
         *
         * @param window    The MetaWindow for which to create the WindowIconActor
         * @param no_redraw If you add multiple windows at once you may want to consider
         *                  settings this to true and when done calling redraw() manually
         * @param temporary Mark the WindowIconActor as temporary. Used for windows dragged over
         *                  the group.
         */
        public void add_window (Meta.Window window, bool no_redraw = false, bool temporary = false) {
            var new_window = new WindowIconActor (wm, window);
            new_window.set_position (32, 32);
            new_window.temporary = temporary;

            icon_container.add_child (new_window);

            if (!no_redraw)
                redraw ();
        }

        /**
         * Remove the WindowIconActor for a MetaWindow from the group
         *
         * @param animate Whether to fade the icon out before removing it
         */
        public void remove_window (Meta.Window window, bool animate = true) {
            foreach (unowned var child in icon_container.get_children ()) {
                unowned var icon = (WindowIconActor) child;
                if (icon.window == window) {
                    if (animate) {
                        icon.save_easing_state ();
                        icon.set_easing_mode (Clutter.AnimationMode.LINEAR);
                        icon.set_easing_duration (wm.enable_animations ? 200 : 0);
                        icon.opacity = 0;
                        icon.restore_easing_state ();

                        var transition = icon.get_transition ("opacity");
                        if (transition != null) {
                            transition.completed.connect (() => {
                                icon.destroy ();
                            });
                        } else {
                            icon.destroy ();
                        }

                    } else {
                        icon.destroy ();
                    }

                    // don't break here! If people spam hover events and we animate
                    // removal, we can actually multiple instances of the same window icon
                }
            }
        }

        /**
         * Sets a hovered actor for the drag action.
         */
        public void set_hovered_actor (Clutter.Actor actor) {
            drag_action.hovered = actor;
        }

        /**
         * Trigger a redraw
         */
        public void redraw () {
            if (!resize_canvas ()) {
                content.invalidate ();
            }
        }

        /**
         * Close handler. We close the workspace by deleting all the windows on it.
         * That way the workspace won't be deleted if windows decide to ignore the
         * delete signal
         */
        private void close () {
            var time = workspace.get_display ().get_current_time ();
            foreach (var window in workspace.list_windows ()) {
                var type = window.window_type;
                if (!window.is_on_all_workspaces () && (type == Meta.WindowType.NORMAL
                    || type == Meta.WindowType.DIALOG || type == Meta.WindowType.MODAL_DIALOG))
                    window.@delete (time);
            }
        }

        /**
         * Draw the background or plus sign and do layouting. We won't lose performance here
         * by relayouting in the same function, as it's only ever called when we invalidate it.
         */
        private bool draw (Cairo.Context cr) {
            cr.set_operator (Cairo.Operator.CLEAR);
            cr.paint ();
            cr.set_operator (Cairo.Operator.OVER);

            var n_windows = icon_container.get_n_children ();

            // single icon => big icon
            if (n_windows == 1) {
                var icon = (WindowIconActor) icon_container.get_child_at_index (0);
                icon.place (0, 0, 64, scale_factor);

                return false;
            }

            // more than one => we need a folder
            Drawing.Utilities.cairo_rounded_rectangle (
                cr,
                0.5 * scale_factor,
                0.5 * scale_factor,
                (int) width - InternalUtils.scale_to_int (1, scale_factor),
                (int) height - InternalUtils.scale_to_int (1, scale_factor),
                InternalUtils.scale_to_int (5, scale_factor)
            );

            if (drag_action.dragging) {
                const double BG_COLOR = 53.0 / 255.0;
                cr.set_source_rgba (BG_COLOR, BG_COLOR, BG_COLOR, 0.7);
            } else {
                cr.set_source_rgba (0, 0, 0, 0.1);
            }

            cr.fill_preserve ();

            cr.set_line_width (InternalUtils.scale_to_int (1, scale_factor));

            var grad = new Cairo.Pattern.linear (0, 0, 0, height);
            grad.add_color_stop_rgba (0.8, 0, 0, 0, 0);
            grad.add_color_stop_rgba (1.0, 1, 1, 1, 0.1);

            cr.set_source (grad);
            cr.stroke ();

            Drawing.Utilities.cairo_rounded_rectangle (
                cr,
                1.5 * scale_factor,
                1.5 * scale_factor,
                (int) width - InternalUtils.scale_to_int (3, scale_factor),
                (int) height - InternalUtils.scale_to_int (3, scale_factor),
                InternalUtils.scale_to_int (5, scale_factor)
            );

            cr.set_source_rgba (0, 0, 0, 0.3);
            cr.stroke ();

            // it's not safe to to call meta_workspace_index() here, we may be still animating something
            // while the workspace is already gone, which would result in a crash.
            unowned Meta.WorkspaceManager manager = workspace.get_display ().get_workspace_manager ();
            int workspace_index = 0;
            for (int i = 0; i < manager.get_n_workspaces (); i++) {
                if (manager.get_workspace_by_index (i) == workspace) {
                    workspace_index = i;
                    break;
                }
            }

            var scaled_size = InternalUtils.scale_to_int (SIZE, scale_factor);

            if (n_windows < 1) {
                if (!Meta.Prefs.get_dynamic_workspaces ()
                    || workspace_index != manager.get_n_workspaces () - 1)
                    return false;

                var buffer = new Drawing.BufferSurface (scaled_size, scaled_size);
                var offset = scaled_size / 2 - InternalUtils.scale_to_int (PLUS_WIDTH, scale_factor) / 2;

                buffer.context.rectangle (
                    InternalUtils.scale_to_int (PLUS_WIDTH / 2, scale_factor) - InternalUtils.scale_to_int (PLUS_SIZE / 2, scale_factor) + 0.5 + offset,
                    0.5 + offset,
                    InternalUtils.scale_to_int (PLUS_SIZE, scale_factor) - 1,
                    InternalUtils.scale_to_int (PLUS_WIDTH, scale_factor) - 1
                );

                buffer.context.rectangle (0.5 + offset,
                    InternalUtils.scale_to_int (PLUS_WIDTH / 2, scale_factor) - InternalUtils.scale_to_int (PLUS_SIZE / 2, scale_factor) + 0.5 + offset,
                    InternalUtils.scale_to_int (PLUS_WIDTH, scale_factor) - 1,
                    InternalUtils.scale_to_int (PLUS_SIZE, scale_factor) - 1
                );

                buffer.context.set_source_rgb (0, 0, 0);
                buffer.context.fill_preserve ();
                buffer.exponential_blur (5);

                buffer.context.set_source_rgb (1, 1, 1);
                buffer.context.set_line_width (1);
                buffer.context.stroke_preserve ();

                buffer.context.set_source_rgb (0.8, 0.8, 0.8);
                buffer.context.fill ();

                cr.set_source_surface (buffer.surface, 0, 0);
                cr.paint ();

                return false;
            }

            int size;
            if (n_windows < 5)
                size = 24;
            else
                size = 16;

            var n_tiled_windows = uint.min (n_windows, 9);
            var columns = (int) Math.ceil (Math.sqrt (n_tiled_windows));
            var rows = (int) Math.ceil (n_tiled_windows / (double) columns);

            int spacing = InternalUtils.scale_to_int (6, scale_factor);

            var width = columns * InternalUtils.scale_to_int (size, scale_factor) + (columns - 1) * spacing;
            var height = rows * InternalUtils.scale_to_int (size, scale_factor) + (rows - 1) * spacing;
            var x_offset = scaled_size / 2 - width / 2;
            var y_offset = scaled_size / 2 - height / 2;

            var show_ellipsis = false;
            var n_shown_windows = n_windows;
            // make place for an ellipsis
            if (n_shown_windows > 9) {
                n_shown_windows = 8;
                show_ellipsis = true;
            }

            var x = x_offset;
            var y = y_offset;
            for (var i = 0; i < n_windows; i++) {
                var window = (WindowIconActor) icon_container.get_child_at_index (i);

                // draw an ellipsis at the 9th position if we need one
                if (show_ellipsis && i == 8) {
                    int top_offset = InternalUtils.scale_to_int (10, scale_factor);
                    int left_offset = InternalUtils.scale_to_int (2, scale_factor);
                    int radius = InternalUtils.scale_to_int (2, scale_factor);
                    int dot_spacing = InternalUtils.scale_to_int (3, scale_factor);
                    cr.arc (left_offset + x, y + top_offset, radius, 0, 2 * Math.PI);
                    cr.arc (left_offset + x + radius + dot_spacing, y + top_offset, radius, 0, 2 * Math.PI);
                    cr.arc (left_offset + x + radius * 2 + dot_spacing * 2, y + top_offset, radius, 0, 2 * Math.PI);

                    cr.set_source_rgb (0.3, 0.3, 0.3);
                    cr.fill ();
                }

                if (i >= n_shown_windows) {
                    window.visible = false;
                    continue;
                }

                window.place (x, y, size, scale_factor);

                x += InternalUtils.scale_to_int (size, scale_factor) + spacing;
                if (x + InternalUtils.scale_to_int (size, scale_factor) >= scaled_size) {
                    x = x_offset;
                    y += InternalUtils.scale_to_int (size, scale_factor) + spacing;
                }
            }

            return false;
        }

        private Clutter.Actor? drag_begin (float click_x, float click_y) {
            unowned Meta.WorkspaceManager manager = workspace.get_display ().get_workspace_manager ();
            if (icon_container.get_n_children () < 1 &&
                Meta.Prefs.get_dynamic_workspaces () &&
                workspace.index () == manager.get_n_workspaces () - 1) {
                return null;
            }

            float abs_x, abs_y;
            float prev_parent_x, prev_parent_y;

            prev_parent = get_parent ();
            prev_parent.get_transformed_position (out prev_parent_x, out prev_parent_y);

            var stage = get_stage ();
            var container = prev_parent as IconGroupContainer;
            if (container != null) {
                container.remove_group_in_place (this);
                container.reset_thumbs (0);
            } else {
                prev_parent.remove_child (this);
            }

            stage.add_child (this);

            get_transformed_position (out abs_x, out abs_y);
            set_position (abs_x + prev_parent_x, abs_y + prev_parent_y);

            toggle_close_button (false);

            // disable reactivity so that workspace thumbs can get events
            reactive = false;

            return this;
        }

        private void drag_end (Clutter.Actor destination) {
            if (destination is WorkspaceInsertThumb) {
                get_parent ().remove_child (this);

                unowned WorkspaceInsertThumb inserter = (WorkspaceInsertThumb) destination;
                unowned Meta.WorkspaceManager manager = workspace.get_display ().get_workspace_manager ();
                manager.reorder_workspace (workspace, inserter.workspace_index);

                restore_group ();
            } else {
                drag_canceled ();
            }
        }

        private void drag_canceled () {
            get_parent ().remove_child (this);
            restore_group ();
        }

        private void restore_group () {
            var container = prev_parent as IconGroupContainer;
            if (container != null) {
                container.add_group (this);
                container.request_reposition (false);
                container.reset_thumbs (WorkspaceInsertThumb.EXPAND_DELAY);
            }
        }
    }
}
