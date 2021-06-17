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

using Clutter;
using Meta;

namespace Gala {
    class WindowShadowEffect : ShadowEffect {
        public unowned Meta.Window window { get; construct; }

        public WindowShadowEffect (Meta.Window window, int shadow_size, int shadow_spread) {
            Object (window: window, shadow_size: shadow_size, shadow_spread: shadow_spread, shadow_opacity: 255);
        }

        public override ActorBox get_bounding_box () {
            var scale_factor = InternalUtils.get_ui_scaling_factor ();
            var size = shadow_size * scale_factor;

            var input_rect = window.get_buffer_rect ();
            var outer_rect = window.get_frame_rect ();

            // Occupy only window frame area plus shadow size
            var bounding_box = ActorBox ();
            bounding_box.set_origin (-(input_rect.x - outer_rect.x) - size, -(input_rect.y - outer_rect.y) - size); //vala-lint=space-before-paren
            bounding_box.set_size (outer_rect.width + size * 2, outer_rect.height + size * 2);

            return bounding_box;
        }
    }

    /**
     * Border to show around the selected window when using keyboard navigation.
     */
    class ActiveShape : Actor {
        private Clutter.Canvas background_canvas;
        private static int border_radius;
        private static Gdk.RGBA color;
        private static const double COLOR_OPACITY = 0.8;

        static construct {
            var label_widget_path = new Gtk.WidgetPath ();
            label_widget_path.append_type (typeof (Gtk.Label));

            var style_context = new Gtk.StyleContext ();
            style_context.add_class (Granite.STYLE_CLASS_CARD);
            style_context.add_class (Granite.STYLE_CLASS_ROUNDED);
            style_context.set_path (label_widget_path);

            border_radius = style_context.get_property (
                Gtk.STYLE_PROPERTY_BORDER_RADIUS,
                Gtk.StateFlags.NORMAL
            ).get_int () * 4;

            color = InternalUtils.get_theme_accent_color ();
        }

        construct {
            background_canvas = new Clutter.Canvas ();
            background_canvas.draw.connect (draw_background);
            content = background_canvas;
        }

        private static bool draw_background (Cairo.Context cr, int width, int height) {
            cr.save ();
            cr.set_operator (Cairo.Operator.CLEAR);
            cr.paint ();
            cr.restore ();

            Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 0, 0, width, height, border_radius);
            cr.set_source_rgba (color.red, color.green, color.blue, COLOR_OPACITY);
            cr.fill ();

            return false;
        }

#if HAS_MUTTER338
        public override void allocate (ActorBox box) {
            base.allocate (box);
#else
        public override void allocate (ActorBox box, AllocationFlags flags) {
            base.allocate (box, flags);
#endif
            color = InternalUtils.get_theme_accent_color ();
            background_canvas.set_size ((int) box.get_width (), (int) box.get_height ());
            background_canvas.invalidate ();
        }
    }

    /**
     * A container for a clone of the texture of a MetaWindow, a WindowIcon, a Tooltip with the title,
     * a close button and a shadow. Used together with the WindowCloneContainer.
     */
    public class WindowClone : Actor {
        const int CLOSE_WINDOW_ICON_SIZE = 36;
        const int WINDOW_ICON_SIZE = 64;
        const int ACTIVE_SHAPE_SIZE = 12;
        const int FADE_ANIMATION_DURATION = 200;
        const int TITLE_MAX_WIDTH_MARGIN = 60;

        /**
         * The window was selected. The MultitaskingView should consider activating
         * the window and closing the view.
         */
        public signal void selected ();

        /**
         * The window was moved or resized and a relayout of the tiling layout may
         * be sensible right now.
         */
        public signal void request_reposition ();

        public Meta.Window window { get; construct; }

        /**
         * The currently assigned slot of the window in the tiling layout. May be null.
         */
        public Meta.Rectangle? slot { get; private set; default = null; }

        public bool dragging { get; private set; default = false; }

        bool _active = false;
        /**
         * When active fades a white border around the window in. Used for the visually
         * indicating the WindowCloneContainer's current_window.
         */
        public bool active {
            get {
                return _active;
            }
            set {
                _active = value;

                active_shape.save_easing_state ();
                active_shape.set_easing_duration (FADE_ANIMATION_DURATION);

                active_shape.opacity = _active ? 255 : 0;

                active_shape.restore_easing_state ();
            }
        }

        public bool overview_mode { get; construct; }
        public GestureTracker? gesture_tracker { get; construct; }

        [CCode (notify = false)]
        public uint8 shadow_opacity {
            get {
                return shadow_effect != null ? shadow_effect.shadow_opacity : 255;
            }
            set {
                if (shadow_effect != null) {
                    shadow_effect.shadow_opacity = value;
                    queue_redraw ();
                }
            }
        }

        DragDropAction? drag_action = null;
        Clone? clone = null;
        ShadowEffect? shadow_effect = null;

        Actor prev_parent = null;
        int prev_index = -1;
        ulong check_confirm_dialog_cb = 0;
        uint shadow_update_timeout = 0;
        bool in_slot_animation = false;

        Actor close_button;
        ActiveShape active_shape;
        Actor window_icon;
        Tooltip window_title;

        public WindowClone (Meta.Window window, GestureTracker? gesture_tracker, bool overview_mode = false) {
            Object (window: window, gesture_tracker: gesture_tracker, overview_mode: overview_mode);
        }

        construct {
            reactive = true;

            window.unmanaged.connect (unmanaged);
            window.notify["on-all-workspaces"].connect (on_all_workspaces_changed);
            window.notify["fullscreen"].connect (check_shadow_requirements);
            window.notify["maximized-horizontally"].connect (check_shadow_requirements);
            window.notify["maximized-vertically"].connect (check_shadow_requirements);

            if (overview_mode) {
                var click_action = new ClickAction ();
                click_action.clicked.connect (() => {
                    actor_clicked (click_action.get_button ());
                });

                add_action (click_action);
            } else {
                drag_action = new DragDropAction (DragDropActionType.SOURCE, "multitaskingview-window");
                drag_action.drag_begin.connect (drag_begin);
                drag_action.destination_crossed.connect (drag_destination_crossed);
                drag_action.drag_end.connect (drag_end);
                drag_action.drag_canceled.connect (drag_canceled);
                drag_action.actor_clicked.connect (actor_clicked);

                add_action (drag_action);
            }

            close_button = Utils.create_close_button ();
            close_button.opacity = 0;
            close_button.set_easing_duration (FADE_ANIMATION_DURATION);
            close_button.button_press_event.connect (() => {
                close_window ();
                return true;
            });

            var scale_factor = InternalUtils.get_ui_scaling_factor ();

            var window_frame_rect = window.get_frame_rect ();
            window_icon = new WindowIcon (window, WINDOW_ICON_SIZE, scale_factor);
            window_icon.opacity = 0;
            window_icon.set_pivot_point (0.5f, 0.5f);
            window_icon.set_easing_duration (MultitaskingView.ANIMATION_DURATION);
            window_icon.set_easing_mode (MultitaskingView.ANIMATION_MODE);
            set_window_icon_position (window_frame_rect.width, window_frame_rect.height);

            window_title = new Tooltip ();
            window_title.opacity = 0;
            window_title.set_easing_duration (FADE_ANIMATION_DURATION);

            active_shape = new ActiveShape ();
            active_shape.opacity = 0;

            add_child (active_shape);
            add_child (window_icon);
            add_child (window_title);
            add_child (close_button);

            load_clone ();
        }

        ~WindowClone () {
            window.unmanaged.disconnect (unmanaged);
            window.notify["on-all-workspaces"].disconnect (on_all_workspaces_changed);
            window.notify["fullscreen"].disconnect (check_shadow_requirements);
            window.notify["maximized-horizontally"].disconnect (check_shadow_requirements);
            window.notify["maximized-vertically"].disconnect (check_shadow_requirements);

            if (shadow_update_timeout != 0)
                Source.remove (shadow_update_timeout);
        }

        /**
         * Waits for the texture of a new WindowActor to be available
         * and makes a close of it. If it was already was assigned a slot
         * at this point it will animate to it. Otherwise it will just place
         * itself at the location of the original window. Also adds the shadow
         * effect and makes sure the shadow is updated on size changes.
         *
         * @param was_waiting Internal argument used to indicate that we had to 
         *                    wait before the window's texture became available.
         */
        void load_clone (bool was_waiting = false) {
            var actor = window.get_compositor_private () as WindowActor;
            if (actor == null) {
                Idle.add (() => {
                    if (window.get_compositor_private () != null)
                        load_clone (true);
                    return false;
                });

                return;
            }

            if (overview_mode)
                actor.hide ();

            clone = new Clone (actor);
            add_child (clone);

            set_child_below_sibling (active_shape, clone);
            set_child_above_sibling (close_button, clone);
            set_child_above_sibling (window_icon, clone);
            set_child_above_sibling (window_title, clone);

            transition_to_original_state (false);

            check_shadow_requirements ();

            if (should_fade ())
                opacity = 0;

            // if we were waiting the view was most probably already opened when our window
            // finally got available. So we fade-in and make sure we took the took place.
            // If the slot is not available however, the view was probably closed while this
            // window was opened, so we stay at our old place.
            if (was_waiting && slot != null) {
                opacity = 0;
                take_slot (slot);
                opacity = 255;

                request_reposition ();
            }
        }

        void check_shadow_requirements () {
            if (window.fullscreen || window.maximized_horizontally && window.maximized_vertically) {
                if (shadow_effect == null) {
                    shadow_effect = new WindowShadowEffect (window, 40, 5);
                    clone.add_effect_with_name ("shadow", shadow_effect);
                }
            } else {
                if (shadow_effect != null) {
                    clone.remove_effect (shadow_effect);
                    shadow_effect = null;
                }
            }
        }

        /**
         * If we are in overview mode, we may display windows from workspaces other than
         * the current one. To ease their appearance we have to fade them in.
         */
        bool should_fade () {
            return (overview_mode
                && window.get_workspace () != window.get_display ().get_workspace_manager ().get_active_workspace ()) || window.minimized;
        }

        void on_all_workspaces_changed () {
            // we don't display windows that are on all workspaces
            if (window.on_all_workspaces)
                unmanaged ();
        }

        /**
         * Place the window at the location of the original MetaWindow
         *
         * @param animate Animate the transformation of the placement
         */
        public void transition_to_original_state (bool animate, bool with_gesture = false, bool is_cancel_animation = false) {
            var outer_rect = window.get_frame_rect ();

            var monitor_geom = window.get_display ().get_monitor_geometry (window.get_monitor ());
            var offset_x = monitor_geom.x;
            var offset_y = monitor_geom.y;

            var initial_x = x;
            var initial_y = y;
            var initial_width = width;
            var initial_height = height;

            var target_x = outer_rect.x - offset_x;
            var target_y = outer_rect.y - offset_y;

            in_slot_animation = true;
            place_widgets (outer_rect.width, outer_rect.height);

            GestureTracker.OnBegin on_animation_begin = () => {
                window_icon.set_easing_duration (0);
            };

            GestureTracker.OnUpdate on_animation_update = (percentage) => {
                var x = GestureTracker.animation_value (initial_x, target_x, percentage);
                var y = GestureTracker.animation_value (initial_y, target_y, percentage);
                var width = GestureTracker.animation_value (initial_width, outer_rect.width, percentage);
                var height = GestureTracker.animation_value (initial_height, outer_rect.height, percentage);
                var opacity = GestureTracker.animation_value (255f, 0f, percentage);

                set_size (width, height);
                set_position (x, y);

                window_icon.opacity = (uint) opacity;
                set_window_icon_position (width, height, false);
            };

            GestureTracker.OnEnd on_animation_end = (percentage, cancel_action) => {
                window_icon.set_easing_duration (MultitaskingView.ANIMATION_DURATION);

                if (cancel_action) {
                    return;
                }

                save_easing_state ();
                set_easing_mode (MultitaskingView.ANIMATION_MODE);
                set_easing_duration (animate ? MultitaskingView.ANIMATION_DURATION : 0);

                set_position (target_x, target_y);
                set_size (outer_rect.width, outer_rect.height);

                if (should_fade ()) {
                    opacity = 0;
                }

                restore_easing_state ();

                if (animate) {
                    toggle_shadow (false);
                }

                window_icon.opacity = 0;
                set_window_icon_position (outer_rect.width, outer_rect.height);

                window_icon.get_transition ("opacity").completed.connect (() => {
                    in_slot_animation = false;
                    place_widgets (outer_rect.width, outer_rect.height);
                });
            };

            if (!animate || gesture_tracker == null || !with_gesture) {
                on_animation_begin (0);
                on_animation_end (1, false, 0);
            } else {
                gesture_tracker.connect_handlers ((owned) on_animation_begin, (owned) on_animation_update, (owned) on_animation_end);
            }
        }

        /**
         * Animate the window to the given slot
         */
        public void take_slot (Meta.Rectangle rect, bool with_gesture = false, bool is_cancel_animation = false) {
            slot = rect;
            var initial_x = x;
            var initial_y = y;
            var initial_width = width;
            var initial_height = height;

            window_icon.opacity = 0;
            window_icon.set_easing_duration (0);

            in_slot_animation = true;
            place_widgets (rect.width, rect.height);

            GestureTracker.OnUpdate on_animation_update = (percentage) => {
                var x = GestureTracker.animation_value (initial_x, rect.x, percentage);
                var y = GestureTracker.animation_value (initial_y, rect.y, percentage);
                var width = GestureTracker.animation_value (initial_width, rect.width, percentage);
                var height = GestureTracker.animation_value (initial_height, rect.height, percentage);
                var opacity = GestureTracker.animation_value (0f, 255f, percentage);

                set_size (width, height);
                set_position (x, y);

                window_icon.opacity = (uint) opacity;
                set_window_icon_position (width, height, false);
            };

            GestureTracker.OnEnd on_animation_end = (percentage, cancel_action) => {
                window_icon.set_easing_duration (MultitaskingView.ANIMATION_DURATION);

                if (cancel_action) {
                    return;
                }

                save_easing_state ();
                set_easing_duration (MultitaskingView.ANIMATION_DURATION);
                set_easing_mode (MultitaskingView.ANIMATION_MODE);

                set_size (rect.width, rect.height);
                set_position (rect.x, rect.y);

                window_icon.opacity = 255;
                set_window_icon_position (rect.width, rect.height);
                restore_easing_state ();

                toggle_shadow (true);

                if (opacity < 255) {
                    save_easing_state ();
                    set_easing_mode (AnimationMode.EASE_OUT_QUAD);
                    set_easing_duration (300);

                    opacity = 255;
                    restore_easing_state ();
                }

                window_icon.get_transition ("opacity").completed.connect (() => {
                    in_slot_animation = false;
                    place_widgets (rect.width, rect.height);
                });
            };

            if (gesture_tracker == null || !with_gesture) {
                on_animation_end (1, false, 0);
            } else {
                gesture_tracker.connect_handlers (null, (owned) on_animation_update, (owned) on_animation_end);
            }
        }

        /**
         * Except for the texture clone and the highlight all children are placed
         * according to their given allocations. The first two are placed in a way
         * that compensates for invisible borders of the texture.
         */
#if HAS_MUTTER338
        public override void allocate (ActorBox box) {
            base.allocate (box);
#else
        public override void allocate (ActorBox box, AllocationFlags flags) {
            base.allocate (box, flags);
#endif

            foreach (var child in get_children ()) {
                if (child != clone && child != active_shape)
#if HAS_MUTTER338
                    child.allocate_preferred_size (child.fixed_x, child.fixed_y);
#else
                    child.allocate_preferred_size (flags);
#endif
            }

            ActorBox shape_alloc = {
                -ACTIVE_SHAPE_SIZE,
                -ACTIVE_SHAPE_SIZE,
                box.get_width () + ACTIVE_SHAPE_SIZE,
                box.get_height () + ACTIVE_SHAPE_SIZE
            };
#if HAS_MUTTER338
            active_shape.allocate (shape_alloc);
#else
            active_shape.allocate (shape_alloc, flags);
#endif

            if (clone == null || dragging)
                return;

            var actor = (WindowActor) window.get_compositor_private ();
            var input_rect = window.get_buffer_rect ();
            var outer_rect = window.get_frame_rect ();
            var scale_factor = (float)width / outer_rect.width;

            ActorBox alloc = {};
            alloc.set_origin ((input_rect.x - outer_rect.x) * scale_factor,
                              (input_rect.y - outer_rect.y) * scale_factor);
            alloc.set_size (actor.width * scale_factor, actor.height * scale_factor);

#if HAS_MUTTER338
            clone.allocate (alloc);
#else
            clone.allocate (alloc, flags);
#endif
        }

        public override bool button_press_event (Clutter.ButtonEvent event) {
            return true;
        }

        public override bool enter_event (Clutter.CrossingEvent event) {
            close_button.opacity = in_slot_animation ? 0 : 255;
            window_title.opacity = in_slot_animation ? 0 : 255;
            return false;
        }

        public override bool leave_event (Clutter.CrossingEvent event) {
            close_button.opacity = 0;
            window_title.opacity = 0;
            return false;
        }

        /**
         * Place the widgets, that is the close button and the WindowIcon of the window,
         * at their positions inside the actor for a given width and height.
         */
        public void place_widgets (int dest_width, int dest_height) {
            Granite.CloseButtonPosition pos;
            Granite.Widgets.Utils.get_default_close_button_position (out pos);
            var scale_factor = InternalUtils.get_ui_scaling_factor ();

            close_button.save_easing_state ();
            window_title.save_easing_state ();
            close_button.set_easing_duration (0);
            window_title.set_easing_duration (0);

            var close_button_size = CLOSE_WINDOW_ICON_SIZE * scale_factor;
            close_button.set_size (close_button_size, close_button_size);

            close_button.y = -close_button.height * 0.33f;

            switch (pos) {
                case Granite.CloseButtonPosition.RIGHT:
                    close_button.x = dest_width - close_button.width * 0.5f;
                    break;
                case Granite.CloseButtonPosition.LEFT:
                    close_button.x = -close_button.width * 0.5f;
                    break;
            }

            bool show = has_pointer && !in_slot_animation;
            close_button.opacity = show ? 255 : 0;
            window_title.opacity = close_button.opacity;

            window_title.set_text (window.get_title (), false);
            window_title.set_max_width (dest_width - (TITLE_MAX_WIDTH_MARGIN * scale_factor));
            set_window_title_position (dest_width, dest_height);

            close_button.restore_easing_state ();
            window_title.restore_easing_state ();
        }

        void toggle_shadow (bool show) {
            if (get_transition ("shadow-opacity") != null)
                remove_transition ("shadow-opacity");

            var shadow_transition = new PropertyTransition ("shadow-opacity") {
                duration = MultitaskingView.ANIMATION_DURATION,
                remove_on_complete = true,
                progress_mode = MultitaskingView.ANIMATION_MODE
            };

            if (show)
                shadow_transition.interval = new Clutter.Interval (typeof (uint8), shadow_opacity, 255);
            else
                shadow_transition.interval = new Clutter.Interval (typeof (uint8), shadow_opacity, 0);

            add_transition ("shadow-opacity", shadow_transition);
        }

        /**
         * Send the window the delete signal and listen for new windows to be added
         * to the window's workspace, in which case we check if the new window is a
         * dialog of the window we were going to delete. If that's the case, we request
         * to select our window.
         */
        void close_window () {
            unowned Meta.Display display = window.get_display ();
            check_confirm_dialog_cb = display.window_entered_monitor.connect (check_confirm_dialog);

            window.@delete (display.get_current_time ());
        }

        void check_confirm_dialog (int monitor, Meta.Window new_window) {
            if (new_window.get_transient_for () == window) {
                Idle.add (() => {
                    selected ();
                    return false;
                });

                SignalHandler.disconnect (window.get_display (), check_confirm_dialog_cb);
                check_confirm_dialog_cb = 0;
            }
        }

        /**
         * The window unmanaged by the compositor, so we need to destroy ourselves too.
         */
        void unmanaged () {
            remove_all_transitions ();

            if (drag_action != null && drag_action.dragging)
                drag_action.cancel ();

            if (clone != null)
                clone.destroy ();

            if (check_confirm_dialog_cb != 0) {
                SignalHandler.disconnect (window.get_display (), check_confirm_dialog_cb);
                check_confirm_dialog_cb = 0;
            }

            if (shadow_update_timeout != 0) {
                Source.remove (shadow_update_timeout);
                shadow_update_timeout = 0;
            }

            destroy ();
        }

        void actor_clicked (uint32 button) {
            switch (button) {
                case 1:
                    selected ();
                    break;
                case 2:
                    close_window ();
                    break;
            }
        }

        /**
         * A drag action has been initiated on us, we reparent ourselves to the stage so
         * we can move freely, scale ourselves to a smaller scale and request that the
         * position we just freed is immediately filled by the WindowCloneContainer.
         */
        Actor drag_begin (float click_x, float click_y) {
            float abs_x, abs_y;
            float prev_parent_x, prev_parent_y;

            prev_parent = get_parent ();
            prev_index = prev_parent.get_children ().index (this);
            prev_parent.get_transformed_position (out prev_parent_x, out prev_parent_y);

            var stage = get_stage ();
            prev_parent.remove_child (this);
            stage.add_child (this);

            active_shape.hide ();

            var scale = window_icon.width / clone.width;

            clone.get_transformed_position (out abs_x, out abs_y);
            clone.save_easing_state ();
            clone.set_easing_duration (FADE_ANIMATION_DURATION);
            clone.set_easing_mode (AnimationMode.EASE_IN_CUBIC);
            clone.set_scale (scale, scale);
            clone.opacity = 0;
            clone.set_pivot_point ((click_x - abs_x) / clone.width, (click_y - abs_y) / clone.height);
            clone.restore_easing_state ();

            request_reposition ();

            get_transformed_position (out abs_x, out abs_y);

            save_easing_state ();
            set_easing_duration (0);
            set_position (abs_x + prev_parent_x, abs_y + prev_parent_y);

            window_icon.save_easing_state ();
            window_icon.set_easing_duration (FADE_ANIMATION_DURATION);
            window_icon.set_easing_mode (AnimationMode.EASE_IN_OUT_CUBIC);
            window_icon.set_position (click_x - (abs_x + prev_parent_x) - window_icon.width / 2,
                click_y - (abs_y + prev_parent_y) - window_icon.height / 2);
            window_icon.restore_easing_state ();

            close_button.opacity = 0;
            window_title.opacity = 0;

            dragging = true;

            return this;
        }

        /**
         * When we cross an IconGroup, we animate to an even smaller size and slightly
         * less opacity and add ourselves as temporary window to the group. When left, 
         * we reverse those steps.
         */
        void drag_destination_crossed (Actor destination, bool hovered) {
            IconGroup? icon_group = destination as IconGroup;
            WorkspaceInsertThumb? insert_thumb = destination as WorkspaceInsertThumb;

            // if we have don't dynamic workspace, we don't allow inserting
            if (icon_group == null && insert_thumb == null
                || (insert_thumb != null && !Prefs.get_dynamic_workspaces ()))
                return;

            // for an icon group, we only do animations if there is an actual movement possible
            if (icon_group != null
                && icon_group.workspace == window.get_workspace ()
                && window.get_monitor () == window.get_display ().get_primary_monitor ())
                return;

            var scale = hovered ? 0.4 : 1.0;
            var opacity = hovered ? 0 : 255;
            var duration = hovered && insert_thumb != null ? insert_thumb.delay : 100;

            window_icon.save_easing_state ();

            window_icon.set_easing_mode (AnimationMode.LINEAR);
            window_icon.set_easing_duration (duration);
            window_icon.set_scale (scale, scale);
            window_icon.set_opacity (opacity);

            window_icon.restore_easing_state ();

            if (insert_thumb != null) {
                insert_thumb.set_window_thumb (window);
            }

            if (icon_group != null) {
                if (hovered)
                    icon_group.add_window (window, false, true);
                else
                    icon_group.remove_window (window);
            }
        }

        /**
         * Depending on the destination we have different ways to find the correct destination.
         * After we found one we destroy ourselves so the dragged clone immediately disappears,
         * otherwise we cancel the drag and animate back to our old place.
         */
        void drag_end (Actor destination) {
            Meta.Workspace workspace = null;
            var primary = window.get_display ().get_primary_monitor ();

            active_shape.show ();

            if (destination is IconGroup) {
                workspace = ((IconGroup) destination).workspace;
            } else if (destination is FramedBackground) {
                workspace = ((WorkspaceClone) destination.get_parent ()).workspace;
            } else if (destination is WorkspaceInsertThumb) {
                if (!Prefs.get_dynamic_workspaces ()) {
                    drag_canceled ();
                    return;
                }

                unowned WorkspaceInsertThumb inserter = (WorkspaceInsertThumb) destination;

                var will_move = window.get_workspace ().index () != inserter.workspace_index;

                if (Prefs.get_workspaces_only_on_primary () && window.get_monitor () != primary) {
                    window.move_to_monitor (primary);
                    will_move = true;
                }

                InternalUtils.insert_workspace_with_window (inserter.workspace_index, window);

                // if we don't actually change workspaces, the window-added/removed signals won't
                // be emitted so we can just keep our window here
                if (!will_move)
                    drag_canceled ();
                else
                    unmanaged ();

                return;
            } else if (destination is MonitorClone) {
                var monitor = ((MonitorClone) destination).monitor;
                if (window.get_monitor () != monitor) {
                    window.move_to_monitor (monitor);
                    unmanaged ();
                } else
                    drag_canceled ();

                return;
            }

            bool did_move = false;

            if (Prefs.get_workspaces_only_on_primary () && window.get_monitor () != primary) {
                window.move_to_monitor (primary);
                did_move = true;
            }

            if (workspace != null && workspace != window.get_workspace ()) {
                window.change_workspace (workspace);
                did_move = true;
            }

            if (did_move)
                unmanaged ();
            else
                // if we're dropped at the place where we came from interpret as cancel
                drag_canceled ();
        }

        /**
         * Animate back to our previous position with a bouncing animation.
         */
        void drag_canceled () {
            get_parent ().remove_child (this);
            prev_parent.insert_child_at_index (this, prev_index);

            clone.save_easing_state ();
            clone.set_pivot_point (0.5f, 0.5f);
            clone.set_easing_duration (250);
            clone.set_easing_mode (AnimationMode.EASE_OUT_QUAD);
            clone.set_scale (1, 1);
            clone.opacity = 255;
            clone.restore_easing_state ();

            request_reposition ();

            // pop 0 animation duration from drag_begin()
            restore_easing_state ();

            window_icon.save_easing_state ();
            window_icon.set_easing_duration (250);
            window_icon.set_easing_mode (AnimationMode.EASE_OUT_QUAD);
            set_window_icon_position (slot.width, slot.height);
            window_icon.restore_easing_state ();

            dragging = false;
        }

        private void set_window_icon_position (float window_width, float window_height, bool aligned = true) {
            var scale_factor = InternalUtils.get_ui_scaling_factor ();
            var size = WINDOW_ICON_SIZE * scale_factor;
            var x = (window_width - size) / 2;
            var y = window_height - (size * 0.75f);

            if (aligned) {
                x = InternalUtils.pixel_align (x);
                y = InternalUtils.pixel_align (y);
            }

            window_icon.set_size (size, size);
            window_icon.set_position (x, y);
        }

        private void set_window_title_position (float window_width, float window_height) {
            var scale_factor = InternalUtils.get_ui_scaling_factor ();
            var x = InternalUtils.pixel_align ((window_width - window_title.width) / 2);
            var y = InternalUtils.pixel_align (window_height - (WINDOW_ICON_SIZE * scale_factor) * 0.75f - (window_title.height / 2) - (18 * scale_factor));
            window_title.set_position (x, y);
        }
    }
}
