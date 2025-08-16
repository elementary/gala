/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022-2025 elementary, Inc. (https://elementary.io)
 *                         2014 Tom Beckmann
 */

/**
 * A container for a clone of the texture of a MetaWindow, a WindowIcon, a Tooltip with the title,
 * a close button and a shadow. Used together with the WindowCloneContainer.
 */
public class Gala.WindowClone : ActorTarget, RootTarget {
    private const int WINDOW_ICON_SIZE = 64;
    private const int ACTIVE_SHAPE_SIZE = 12;
    private const int FADE_ANIMATION_DURATION = 200;
    private const int TITLE_MAX_WIDTH_MARGIN = 60;
    private const int CLOSE_TRANSLATION = 600;

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

    public WindowManager wm { get; construct; }
    public Meta.Window window { get; construct; }

    /**
     * The currently assigned slot of the window in the tiling layout. May be null.
     */
    public Mtk.Rectangle? slot { get; private set; default = null; }

    /**
     * When active fades a white border around the window in. Used for the visually
     * indicating the WindowCloneContainer's current_window.
     */
    public bool active {
        set {
            active_shape.update_color ();

            active_shape.save_easing_state ();
            active_shape.set_easing_duration (Utils.get_animation_duration (FADE_ANIMATION_DURATION));
            active_shape.opacity = value ? 255 : 0;
            active_shape.restore_easing_state ();
        }
    }

    public bool overview_mode { get; construct; }
    public float monitor_scale { get; construct set; }

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

    private DragDropAction? drag_action = null;
    private ShadowEffect? shadow_effect = null;

    private Clutter.Actor prev_parent = null;
    private int prev_index = -1;
    private ulong check_confirm_dialog_cb = 0;
    private bool in_slot_animation = false;

    private Clutter.Clone clone;
    private Clutter.Actor windows_container;
    private Gala.CloseButton close_button;
    private ActiveShape active_shape;
    private Clutter.Actor window_icon;
    private Tooltip window_title;
    private HashTable<Meta.Window, Clutter.Clone> child_clones = new HashTable<Meta.Window, Clutter.Clone> (null, null);

    private GestureController gesture_controller;

    public WindowClone (WindowManager wm, Meta.Window window, float monitor_scale, bool overview_mode = false)
    requires (window.get_compositor_private () != null) {
        Object (
            wm: wm,
            window: window,
            monitor_scale: monitor_scale,
            overview_mode: overview_mode
        );
    }

    construct {
        reactive = true;

        gesture_controller = new GestureController (CUSTOM, wm);
        gesture_controller.enable_scroll (this, VERTICAL);
        add_gesture_controller (gesture_controller);

        window.unmanaged.connect (unmanaged);
        window.notify["fullscreen"].connect (check_shadow_requirements);
        window.notify["maximized-horizontally"].connect (check_shadow_requirements);
        window.notify["maximized-vertically"].connect (check_shadow_requirements);
        window.notify["minimized"].connect (update_targets);
        window.position_changed.connect (update_targets);
        window.size_changed.connect (() => request_reposition ());

        if (overview_mode) {
            var click_action = new Clutter.ClickAction ();
            click_action.clicked.connect ((action, actor) => {
                actor_clicked (action.get_button ());
            });

            add_action (click_action);
        } else {
            drag_action = new DragDropAction (DragDropActionType.SOURCE, "multitaskingview-window");
            drag_action.drag_begin.connect (drag_begin);
            drag_action.destination_crossed.connect (destination_crossed);
            drag_action.destination_motion.connect (destination_motion);
            drag_action.drag_end.connect (drag_end);
            drag_action.drag_canceled.connect (drag_canceled);
            drag_action.actor_clicked.connect (actor_clicked);

            add_action (drag_action);
        }

        active_shape = new ActiveShape () {
            opacity = 0
        };

        clone = new Clutter.Clone ((Meta.WindowActor) window.get_compositor_private ());

        windows_container = new Clutter.Actor ();
        windows_container.add_child (clone);

        window_title = new Tooltip ();

        add_child (active_shape);
        add_child (windows_container);
        add_child (window_title);

        notify["monitor-scale"].connect (reallocate);
        reallocate ();

        check_shadow_requirements ();

        window.notify["title"].connect (() => window_title.set_text (window.get_title () ?? ""));
        window_title.set_text (window.get_title () ?? "");

        notify["has-pointer"].connect (() => update_hover_widgets ());

        unowned var display = wm.get_display ();
        foreach (unowned var child_window in display.list_all_windows ()) {
            InternalUtils.wait_for_window_actor_visible (
                child_window,
                (window_actor) => add_child_window (window_actor.meta_window)
            );
        }

        display.window_created.connect (
            (new_window) => InternalUtils.wait_for_window_actor_visible (
                new_window,
                (window_actor) => add_child_window (window_actor.meta_window)
            )
        );
    }

    private void add_child_window (Meta.Window new_window) requires (new_window.get_compositor_private () != null) {
        if (new_window == window || !window.is_ancestor_of_transient (new_window) && new_window.find_root_ancestor () != window) {
            return;
        }

        unowned var new_window_actor = (Meta.WindowActor) new_window.get_compositor_private ();
        var actor_clone = new Clutter.Clone (new_window_actor);
        windows_container.add_child (actor_clone);

        child_clones.insert (new_window, actor_clone);

        new_window.unmanaged.connect ((new_window) => {
            windows_container.remove_child (child_clones.take (new_window));
        });

        update_targets ();
    }

    ~WindowClone () {
        window.unmanaged.disconnect (unmanaged);
        window.notify["fullscreen"].disconnect (check_shadow_requirements);
        window.notify["maximized-horizontally"].disconnect (check_shadow_requirements);
        window.notify["maximized-vertically"].disconnect (check_shadow_requirements);
        window.notify["minimized"].disconnect (update_targets);
        window.position_changed.disconnect (update_targets);
    }

    private void reallocate () {
        close_button = new Gala.CloseButton (monitor_scale) {
            opacity = 0
        };
        close_button.triggered.connect (close_window);
        close_button.notify["has-pointer"].connect (() => update_hover_widgets ());

        window_icon = new WindowIcon (window, WINDOW_ICON_SIZE, (int)Math.round (monitor_scale)) {
            visible = !overview_mode
        };
        window_icon.opacity = 0;
        window_icon.set_pivot_point (0.5f, 0.5f);

        add_child (close_button);
        add_child (window_icon);

        set_child_below_sibling (window_icon, window_title);
    }

    private void check_shadow_requirements () {
        if (window.fullscreen || window.maximized_horizontally && window.maximized_vertically) {
            if (shadow_effect == null) {
                shadow_effect = new ShadowEffect ("window", monitor_scale);
                shadow_opacity = 0;
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
    private bool should_fade () {
        return (overview_mode
            && window.get_workspace () != window.get_display ().get_workspace_manager ().get_active_workspace ()) || window.minimized;
    }

    /**
     * Animate the window to the given slot
     */
    public void take_slot (Mtk.Rectangle rect, bool animate) {
        slot = rect;

        if (animate) {
            save_easing_state ();
            set_easing_duration (Utils.get_animation_duration (MultitaskingView.ANIMATION_DURATION));
            set_easing_mode (EASE_OUT_QUAD);
        }

        update_targets ();

        if (animate) {
            restore_easing_state ();
        }
    }

    private void update_targets () {
        remove_all_targets ();

        if (slot == null) {
            return;
        }

        var window_rect = window.get_frame_rect ();
        var monitor_geometry = window.display.get_monitor_geometry (window.get_monitor ());

        add_target (new PropertyTarget (MULTITASKING_VIEW, this, "x", typeof (float), (float) (window_rect.x - monitor_geometry.x), (float) slot.x));
        add_target (new PropertyTarget (MULTITASKING_VIEW, this, "y", typeof (float), (float) (window_rect.y - monitor_geometry.y), (float) slot.y));
        add_target (new PropertyTarget (MULTITASKING_VIEW, this, "width", typeof (float), (float) window_rect.width, (float) slot.width));
        add_target (new PropertyTarget (MULTITASKING_VIEW, this, "height", typeof (float), (float) window_rect.height, (float) slot.height));
        add_target (new PropertyTarget (MULTITASKING_VIEW, this, "shadow-opacity", typeof (uint8), (uint8) 0u, (uint8) 255u));
        if (should_fade ()) {
            add_target (new PropertyTarget (MULTITASKING_VIEW, this, "opacity", typeof (uint8), (uint8) 0u, (uint8) 255u));
        }

        add_target (new PropertyTarget (MULTITASKING_VIEW, window_icon, "opacity", typeof (uint), 0u, 255u));

        add_target (new PropertyTarget (MULTITASKING_VIEW, window_title, "opacity", typeof (uint), 0u, 255u));

        var window_buffer_rect = window.get_buffer_rect ();
        var window_shadow_spread_x = window_rect.x - window_buffer_rect.x;
        var window_shadow_spread_y = window_rect.y - window_buffer_rect.y;

        child_clones.foreach ((child_window, child_clone) => {
            var child_buffer_rect = child_window.get_buffer_rect ();
            var child_frame_rect = child_window.get_frame_rect ();

            var scale = 1.0f;
            if (child_frame_rect.width > window_rect.width || child_frame_rect.height > window_rect.height) {
                scale = float.min ((float) window_rect.width / child_frame_rect.width, (float) window_rect.height / child_frame_rect.height);

                add_target (new PropertyTarget (MULTITASKING_VIEW, child_clone, "width", typeof (float), (float) child_buffer_rect.width, child_buffer_rect.width * scale));
                add_target (new PropertyTarget (MULTITASKING_VIEW, child_clone, "height", typeof (float), (float) child_buffer_rect.height, child_buffer_rect.height * scale));
            }

            var child_parent_x_diff = child_buffer_rect.x - window_buffer_rect.x;
            var child_parent_y_diff = child_buffer_rect.y - window_buffer_rect.y;

            // Center the window
            var child_shadow_spread_x = (child_frame_rect.x - child_buffer_rect.x) * scale;
            var child_shadow_spread_y = (child_frame_rect.y - child_buffer_rect.y) * scale;
            var target_x = window_shadow_spread_x - child_shadow_spread_x + (window_rect.width - child_frame_rect.width * scale) / 2.0f;
            var target_y = window_shadow_spread_y - child_shadow_spread_y + (window_rect.height - child_frame_rect.height * scale) / 2.0f;

            add_target (new PropertyTarget (MULTITASKING_VIEW, child_clone, "x", typeof (float), (float) child_parent_x_diff, target_x));
            add_target (new PropertyTarget (MULTITASKING_VIEW, child_clone, "y", typeof (float), (float) child_parent_y_diff, target_y));
        });
    }

    public override void start_progress (GestureAction action) {
        update_hover_widgets (true);
    }

    public override void update_progress (Gala.GestureAction action, double progress) {
        if (action != CUSTOM || slot == null || !Meta.Prefs.get_gnome_animations ()) {
            return;
        }

        var target_translation_y = (float) (-CLOSE_TRANSLATION * monitor_scale * progress);
        var target_opacity = (uint) (255 * (1 - progress));

        windows_container.translation_y = target_translation_y;
        windows_container.opacity = target_opacity;

        window_icon.translation_y = target_translation_y;
        window_icon.opacity = target_opacity;

        window_title.translation_y = target_translation_y;
        window_title.opacity = target_opacity;

        close_button.translation_y = target_translation_y;
        close_button.opacity = target_opacity;
    }

    public override void end_progress (GestureAction action) {
        update_hover_widgets (false);

        if (action == CUSTOM && get_current_commit (CUSTOM) > 0.5 && Meta.Prefs.get_gnome_animations ()) {
            close_window (Meta.CURRENT_TIME);
        }
    }

    public override void allocate (Clutter.ActorBox box) {
        base.allocate (box);

        if (drag_action != null && drag_action.dragging) {
            return;
        }

        var buffer_rect = window.get_buffer_rect ();
        var frame_rect = window.get_frame_rect ();
        var scale_factor = width / frame_rect.width;

        // Compensate for invisible borders of the texture
        var shadow_offset_x = buffer_rect.x - frame_rect.x;
        var shadow_offset_y = buffer_rect.y - frame_rect.y;

        windows_container.set_scale (scale_factor, scale_factor);
        float preferred_width, preferred_height;
        windows_container.get_preferred_size (null, null, out preferred_width, out preferred_height);

        windows_container.allocate (InternalUtils.actor_box_from_rect (shadow_offset_x * scale_factor, shadow_offset_y * scale_factor, preferred_width, preferred_height));

        Clutter.ActorBox shape_alloc = {
            -ACTIVE_SHAPE_SIZE,
            -ACTIVE_SHAPE_SIZE,
            box.get_width () + ACTIVE_SHAPE_SIZE,
            box.get_height () + ACTIVE_SHAPE_SIZE
        };
        Clutter.ActorBox.clamp_to_pixel (ref shape_alloc);
        active_shape.allocate (shape_alloc);

        float close_button_width, close_button_height;
        close_button.get_preferred_size (null, null, out close_button_width, out close_button_height);

        var close_button_x = is_close_button_on_left () ?
            -close_button_width * 0.5f : box.get_width () - close_button_width * 0.5f;

        var close_button_alloc = InternalUtils.actor_box_from_rect (close_button_x, -close_button_height * 0.33f, close_button_width, close_button_height);
        close_button.allocate (close_button_alloc);

        float window_icon_width, window_icon_height;
        window_icon.get_preferred_size (null, null, out window_icon_width, out window_icon_height);

        var window_icon_x = (box.get_width () - window_icon_width) / 2;
        var window_icon_y = box.get_height () - (window_icon_height * 0.75f);

        var window_icon_alloc = InternalUtils.actor_box_from_rect (window_icon_x, window_icon_y, window_icon_width, window_icon_height);
        window_icon.allocate (window_icon_alloc);

        unowned var display = wm.get_display ();
        var rect = get_transformed_extents ();
        var monitor_index = display.get_monitor_index_for_rect (Mtk.Rectangle.from_graphene_rect (rect, ROUND));
        var monitor_scale = display.get_monitor_scale (monitor_index);

        float window_title_max_width = box.get_width () - Utils.scale_to_int (TITLE_MAX_WIDTH_MARGIN, monitor_scale);
        float window_title_height, window_title_nat_width;
        window_title.get_preferred_size (null, null, out window_title_nat_width, out window_title_height);

        var window_title_width = window_title_nat_width.clamp (0, window_title_max_width);

        float window_title_x = (box.get_width () - window_title_width) / 2;
        float window_title_y = (window_icon.visible ? window_icon_y : box.get_height ()) - (window_title_height / 2) - Utils.scale_to_int (18, monitor_scale);

        var window_title_alloc = InternalUtils.actor_box_from_rect (window_title_x, window_title_y, window_title_width, window_title_height);
        window_title.allocate (window_title_alloc);
    }

    public override bool button_press_event (Clutter.Event event) {
        return Clutter.EVENT_STOP;
    }

    private void update_hover_widgets (bool? animating = null) {
        if (animating != null) {
            in_slot_animation = animating;
        }

        var duration = Utils.get_animation_duration (FADE_ANIMATION_DURATION);

        var show = (has_pointer || close_button.has_pointer) && !in_slot_animation;

        close_button.save_easing_state ();
        close_button.set_easing_mode (Clutter.AnimationMode.LINEAR);
        close_button.set_easing_duration (duration);
        close_button.opacity = show ? 255 : 0;
        close_button.restore_easing_state ();
    }

    /**
     * Send the window the delete signal and listen for new windows to be added
     * to the window's workspace, in which case we check if the new window is a
     * dialog of the window we were going to delete. If that's the case, we request
     * to select our window.
     */
    private void close_window (uint32 timestamp) {
        unowned var display = window.get_display ();
        check_confirm_dialog_cb = display.window_entered_monitor.connect (check_confirm_dialog);

        window.@delete (timestamp);
    }

    private void check_confirm_dialog (int monitor, Meta.Window new_window) {
        Idle.add (() => {
            if (new_window.get_transient_for () == window) {
                gesture_controller.goto (0.0);
                selected ();

                SignalHandler.disconnect (window.get_display (), check_confirm_dialog_cb);
                check_confirm_dialog_cb = 0;
            }

            return Source.REMOVE;
        });
    }

    /**
     * The window unmanaged by the compositor, so we need to destroy ourselves too.
     */
    private void unmanaged () {
        remove_all_transitions ();

        if (drag_action != null && drag_action.dragging) {
            drag_action.cancel ();
        }

        clone.destroy ();

        if (check_confirm_dialog_cb != 0) {
            SignalHandler.disconnect (window.get_display (), check_confirm_dialog_cb);
            check_confirm_dialog_cb = 0;
        }

        destroy ();
    }

    private void actor_clicked (uint32 button, Clutter.InputDeviceType device_type = POINTER_DEVICE) {
        if (button == Clutter.Button.PRIMARY) {
            selected ();
        } else if (button == Clutter.Button.MIDDLE && device_type == POINTER_DEVICE) {
            close_window (wm.get_display ().get_current_time ());
        }
    }

    /**
     * A drag action has been initiated on us, we reparent ourselves to the stage so
     * we can move freely, scale ourselves to a smaller scale and request that the
     * position we just freed is immediately filled by the WindowCloneContainer.
     */
    private Clutter.Actor drag_begin (float click_x, float click_y) {
        var last_window_icon_x = window_icon.x;
        var last_window_icon_y = window_icon.y;

        float abs_x, abs_y;
        float prev_parent_x, prev_parent_y;

        prev_parent = get_parent ();
        prev_index = prev_parent.get_children ().index (this);
        prev_parent.get_transformed_position (out prev_parent_x, out prev_parent_y);

        var stage = get_stage ();
        prev_parent.remove_child (this);
        stage.add_child (this);

        active_shape.hide ();

        var scale = window_icon.width / windows_container.width;
        var duration = Utils.get_animation_duration (FADE_ANIMATION_DURATION);

        windows_container.get_transformed_position (out abs_x, out abs_y);
        windows_container.save_easing_state ();
        windows_container.set_easing_duration (duration);
        windows_container.set_easing_mode (Clutter.AnimationMode.EASE_IN_CUBIC);
        windows_container.set_pivot_point ((click_x - abs_x) / windows_container.width, (click_y - abs_y) / windows_container.height);
        windows_container.set_scale (scale, scale);
        windows_container.opacity = 0;
        windows_container.restore_easing_state ();

        request_reposition ();

        get_transformed_position (out abs_x, out abs_y);

        set_position (abs_x + prev_parent_x, abs_y + prev_parent_y);

        // Set the last position so that it animates from there and not 0, 0
        window_icon.set_position (last_window_icon_x, last_window_icon_y);

        window_icon.save_easing_state ();
        window_icon.set_easing_duration (duration);
        window_icon.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_CUBIC);
        window_icon.set_position (
            click_x - (abs_x + prev_parent_x) - window_icon.width / 2,
            click_y - (abs_y + prev_parent_y) - window_icon.height / 2
        );
        window_icon.restore_easing_state ();

        close_button.opacity = 0;
        window_title.opacity = 0;

#if HAS_MUTTER48
        wm.get_display ().set_cursor (Meta.Cursor.MOVE);
#else
        wm.get_display ().set_cursor (Meta.Cursor.DND_IN_DRAG);
#endif

        return this;
    }

    private void destination_crossed (Clutter.Actor destination, bool hovered) {
        if (!(destination is Meta.WindowActor)) {
            return;
        }

        if (hovered) {
            WindowDragProvider.get_instance ().notify_enter (window.get_id ());
        } else {
            WindowDragProvider.get_instance ().notify_leave ();
        }
    }

    private void destination_motion (Clutter.Actor destination, float x, float y) {
        WindowDragProvider.get_instance ().notify_motion (x, y);
    }

    /**
     * Depending on the destination we have different ways to find the correct destination.
     * After we found one we destroy ourselves so the dragged clone immediately disappears,
     * otherwise we cancel the drag and animate back to our old place.
     */
    private void drag_end (Clutter.Actor destination) {
        unowned var display = wm.get_display ();

        Meta.Workspace workspace = null;
        var primary = display.get_primary_monitor ();

        active_shape.show ();

        display.set_cursor (Meta.Cursor.DEFAULT);

        if (destination is FramedBackground) {
            workspace = ((WorkspaceClone) destination.get_parent ()).workspace;
        } else if (destination is MonitorClone) {
            var monitor = ((MonitorClone) destination).monitor;
            if (window.get_monitor () != monitor) {
                window.move_to_monitor (monitor);
                unmanaged ();
            } else {
                drag_canceled ();
            }

            return;
        } else if (destination is Meta.WindowActor) {
            WindowDragProvider.get_instance ().notify_dropped ();
        }

        bool did_move = false;

        if (Meta.Prefs.get_workspaces_only_on_primary () && !window.is_on_primary_monitor ()) {
            window.move_to_monitor (primary);
            did_move = true;
        }

        if (workspace != null && workspace != window.get_workspace ()) {
            window.change_workspace (workspace);
            did_move = true;
        }

        if (did_move) {
            unmanaged ();
        } else {
            // if we're dropped at the place where we came from interpret as cancel
            drag_canceled ();
        }
    }

    /**
     * Animate back to our previous position with a bouncing animation.
     */
    private void drag_canceled () {
        get_parent ().remove_child (this);

        var duration = Utils.get_animation_duration (MultitaskingView.ANIMATION_DURATION);

        // Adding to the previous parent will automatically update it to take it's slot
        // so to animate it we set the easing
        save_easing_state ();
        set_easing_duration (duration);
        set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        prev_parent.add_child (this); // Add above so that it is above while it animates back to its place
        restore_easing_state ();

        windows_container.set_pivot_point (0.0f, 0.0f);
        windows_container.save_easing_state ();
        windows_container.set_easing_duration (duration);
        windows_container.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        windows_container.set_scale (1, 1);
        windows_container.opacity = 255;
        windows_container.restore_easing_state ();

        request_reposition ();

        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);

        if (duration > 0) {
            ulong handler = 0;
            handler = windows_container.transitions_completed.connect (() => {
                prev_parent.set_child_at_index (this, prev_index); // Set the correct index so that correct stacking order is kept
                windows_container.disconnect (handler);
            });
        } else {
            prev_parent.set_child_at_index (this, prev_index); // Set the correct index so that correct stacking order is kept
        }
    }

    private static bool is_close_button_on_left () {
        var layout = Meta.Prefs.get_button_layout ();
        foreach (var button_function in layout.left_buttons) {
            if (button_function == Meta.ButtonFunction.CLOSE) {
                return true;
            }
        }

        return false;
    }

    /**
     * Border to show around the selected window when using keyboard navigation.
     */
    private class ActiveShape : Clutter.Actor {
        private const int BORDER_RADIUS = 16;
        private const double COLOR_OPACITY = 0.8;

        construct {
            add_effect (new RoundedCornersEffect (BORDER_RADIUS, 1.0f));
        }

        public void update_color () {
            var accent_color = Drawing.StyleManager.get_instance ().theme_accent_color;
            background_color = {
                (uint8) (accent_color.red * uint8.MAX),
                (uint8) (accent_color.green * uint8.MAX),
                (uint8) (accent_color.blue * uint8.MAX),
                (uint8) (COLOR_OPACITY * uint8.MAX)
            };
        }
    }
}
