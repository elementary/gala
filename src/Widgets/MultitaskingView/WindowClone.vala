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

    public Clutter.Actor? actor { get { return this; } }
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
    private Clutter.Clone? clone = null;
    private ShadowEffect? shadow_effect = null;

    private Clutter.Clone? drag_handle = null;

    private ulong check_confirm_dialog_cb = 0;
    private bool in_slot_animation = false;

    private Clutter.Actor clone_container;
    private Gala.CloseButton close_button;
    private ActiveShape active_shape;
    private Clutter.Actor window_icon;
    private Tooltip window_title;

    private GestureController gesture_controller;

    public WindowClone (WindowManager wm, Meta.Window window, float monitor_scale, bool overview_mode = false) {
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

        active_shape = new ActiveShape (monitor_scale) {
            opacity = 0
        };
        bind_property ("monitor-scale", active_shape, "monitor-scale");

        clone_container = new Clutter.Actor () {
            pivot_point = { 0.5f, 0.5f }
        };

        window_title = new Tooltip (monitor_scale);
        bind_property ("monitor-scale", window_title, "monitor-scale");

        close_button = new Gala.CloseButton (monitor_scale) {
            opacity = 0
        };
        bind_property ("monitor-scale", close_button, "monitor-scale");
        close_button.triggered.connect (close_window);
        close_button.notify["has-pointer"].connect (() => update_hover_widgets ());

        add_child (active_shape);
        add_child (clone_container);
        add_child (window_title);
        add_child (close_button);

        notify["monitor-scale"].connect (reallocate);
        reallocate ();

        InternalUtils.wait_for_window_actor (window, load_clone);

        window.notify["title"].connect (() => window_title.set_text (window.get_title () ?? ""));
        window_title.set_text (window.get_title () ?? "");

        notify["has-pointer"].connect (() => update_hover_widgets ());
    }

    ~WindowClone () {
        window.unmanaged.disconnect (unmanaged);
        window.notify["fullscreen"].disconnect (check_shadow_requirements);
        window.notify["maximized-horizontally"].disconnect (check_shadow_requirements);
        window.notify["maximized-vertically"].disconnect (check_shadow_requirements);
        window.notify["minimized"].disconnect (update_targets);
        window.position_changed.disconnect (update_targets);

        finish_drag ();
    }

    private void reallocate () {
        window_icon = new WindowIcon (window, WINDOW_ICON_SIZE, (int)Math.round (monitor_scale)) {
            visible = !overview_mode
        };
        window_icon.opacity = 0;
        window_icon.set_pivot_point (0.5f, 0.5f);

        add_child (window_icon);

        set_child_below_sibling (window_icon, window_title);
    }

    /**
     * Waits for the texture of a new Meta.WindowActor to be available
     * and makes a close of it. If it was already was assigned a slot
     * at this point it will animate to it. Otherwise it will just place
     * itself at the location of the original window. Also adds the shadow
     * effect and makes sure the shadow is updated on size changes.
     */
    private void load_clone (Meta.WindowActor actor) {
        clone = new Clutter.Clone (actor);
        clone_container.add_child (clone);

        check_shadow_requirements ();
    }

    private void check_shadow_requirements () {
        if (clone == null) {
            return;
        }

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

        clone_container.translation_y = target_translation_y;
        clone_container.opacity = target_opacity;

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

        var input_rect = window.get_buffer_rect ();
        var outer_rect = window.get_frame_rect ();
        var clone_scale_factor = width / outer_rect.width;

        // Compensate for invisible borders of the texture
        float clone_x = (input_rect.x - outer_rect.x) * clone_scale_factor;
        float clone_y = (input_rect.y - outer_rect.y) * clone_scale_factor;

        var clone_container_alloc = InternalUtils.actor_box_from_rect (clone_x, clone_y, input_rect.width * clone_scale_factor, input_rect.height * clone_scale_factor);
        clone_container.allocate (clone_container_alloc);

        if (clone == null || (drag_action != null && drag_action.dragging)) {
            return;
        }

        unowned var display = wm.get_display ();

        clone.set_scale (clone_scale_factor, clone_scale_factor);

        float clone_width, clone_height;
        clone.get_preferred_size (null, null, out clone_width, out clone_height);

        var clone_alloc = InternalUtils.actor_box_from_rect (0, 0, clone_width, clone_height);
        clone.allocate (clone_alloc);

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

        if (clone != null) {
            clone.destroy ();
        }

        if (check_confirm_dialog_cb != 0) {
            SignalHandler.disconnect (window.get_display (), check_confirm_dialog_cb);
            check_confirm_dialog_cb = 0;
        }
    }

    private void actor_clicked (uint32 button, Clutter.InputDeviceType device_type = POINTER_DEVICE) {
        if (button == Clutter.Button.PRIMARY) {
            selected ();
        } else if (button == Clutter.Button.MIDDLE && device_type == POINTER_DEVICE) {
            close_window (wm.get_display ().get_current_time ());
        }
    }

    /**
     * A drag action has been initiated on us, we scale ourselves to a smaller scale and
     * provide a clone of ourselves as drag handle so that it can move freely.
     */
    private Clutter.Actor drag_begin (float click_x, float click_y) requires (drag_handle == null) {
        active_shape.hide ();

        var scale = window_icon.width / clone.width;
        var duration = Utils.get_animation_duration (FADE_ANIMATION_DURATION);

        float abs_x, abs_y;
        clone.get_transformed_position (out abs_x, out abs_y);
        clone.save_easing_state ();
        clone.set_easing_duration (duration);
        clone.set_easing_mode (Clutter.AnimationMode.EASE_IN_CUBIC);
        clone.set_pivot_point ((click_x - abs_x) / clone.width, (click_y - abs_y) / clone.height);
        clone.set_scale (scale, scale);
        clone.opacity = 0;
        clone.restore_easing_state ();

        get_transformed_position (out abs_x, out abs_y);

        window_icon.save_easing_state ();
        window_icon.set_easing_duration (duration);
        window_icon.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_CUBIC);
        window_icon.set_position (
            click_x - abs_x - window_icon.width / 2,
            click_y - abs_y - window_icon.height / 2
        );
        window_icon.restore_easing_state ();

        close_button.visible = false;
        window_title.visible = false;

#if HAS_MUTTER48
        wm.get_display ().set_cursor (Meta.Cursor.MOVE);
#else
        wm.get_display ().set_cursor (Meta.Cursor.DND_IN_DRAG);
#endif

        drag_handle = new Clutter.Clone (this);
        drag_handle.set_position (abs_x, abs_y);
        get_stage ().add_child (drag_handle);

        visible = false;

        return drag_handle;
    }

    private void destination_crossed (Clutter.Actor destination, bool hovered) {
#if !OLD_ICON_GROUPS
        if (!(destination is Meta.WindowActor)) {
            return;
        }

        if (hovered) {
            WindowDragProvider.get_instance ().notify_enter (window.get_id ());
        } else {
            WindowDragProvider.get_instance ().notify_leave ();
        }
#else
        var icon_group = destination as IconGroup;
        var insert_thumb = destination as WorkspaceInsertThumb;

        // if we have don't dynamic workspace, we don't allow inserting
        if (icon_group == null && insert_thumb == null
            || (insert_thumb != null && !Meta.Prefs.get_dynamic_workspaces ())) {
                return;
        }

        // for an icon group, we only do animations if there is an actual movement possible
        if (icon_group != null
            && icon_group.workspace == window.get_workspace ()
            && window.is_on_primary_monitor ()) {
                return;
        }

        var scale = hovered ? 0.4 : 1.0;
        var opacity = hovered ? 0 : 255;
        uint duration = hovered && insert_thumb != null ? insert_thumb.delay : 100;
        duration = Utils.get_animation_duration (duration);

        window_icon.save_easing_state ();

        window_icon.set_easing_mode (Clutter.AnimationMode.LINEAR);
        window_icon.set_easing_duration (duration);
        window_icon.set_scale (scale, scale);
        window_icon.set_opacity (opacity);

        window_icon.restore_easing_state ();

        if (insert_thumb != null) {
            insert_thumb.set_window_thumb (window);
        }

        if (icon_group != null) {
            if (hovered) {
                icon_group.add_window (window, false, true);
            } else {
                icon_group.remove_window (window, false);
            }
        }

#if HAS_MUTTER48
        wm.get_display ().set_cursor (hovered ? Meta.Cursor.MOVE : Meta.Cursor.NO_DROP);
#else
        wm.get_display ().set_cursor (hovered ? Meta.Cursor.DND_MOVE : Meta.Cursor.DND_IN_DRAG);
#endif
#endif
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

        active_shape.show ();

        display.set_cursor (Meta.Cursor.DEFAULT);

        bool did_move = false;

        if (destination is FramedBackground) {
            var primary = display.get_primary_monitor ();
            if (Meta.Prefs.get_workspaces_only_on_primary () && window.get_monitor () != primary) {
                window.move_to_monitor (primary);
                did_move = true;
            }

            var workspace = ((WorkspaceClone) destination.get_parent ()).workspace;
            if (workspace != window.get_workspace ()) {
                window.change_workspace (workspace);
                did_move = true;
            }
        } else if (destination is MonitorClone) {
            var monitor = ((MonitorClone) destination).monitor;
            if (window.get_monitor () != monitor) {
                window.move_to_monitor (monitor);
                did_move = true;
            }
        } else if (destination is Meta.WindowActor) {
            WindowDragProvider.get_instance ().notify_dropped ();
        }

        if (did_move) {
            finish_drag ();
        } else {
            // if we're dropped at the place where we came from interpret as cancel
            drag_canceled ();
        }
    }

    /**
     * Animate back to our previous position with a bouncing animation.
     */
    private void drag_canceled () {
        var duration = Utils.get_animation_duration (MultitaskingView.ANIMATION_DURATION);

        float target_x, target_y;
        get_transformed_position (out target_x, out target_y);
        drag_handle.save_easing_state ();
        drag_handle.set_easing_duration (duration);
        drag_handle.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        drag_handle.set_position (target_x, target_y);
        drag_handle.restore_easing_state ();

        clone.set_pivot_point (0.0f, 0.0f);
        clone.save_easing_state ();
        clone.set_easing_duration (duration);
        clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        clone.set_scale (1, 1);
        clone.opacity = 255;
        clone.restore_easing_state ();

        close_button.visible = true;
        window_title.visible = true;

        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);

        if (duration > 0) {
            ulong handler = 0;
            handler = drag_handle.transitions_completed.connect (() => {
                drag_handle.disconnect (handler);
                finish_drag ();
                visible = true;
            });
        } else {
            finish_drag ();
            visible = true;
        }
    }

    private void finish_drag () {
        if (drag_handle != null) {
            drag_handle.get_stage ().remove_child (drag_handle);
            drag_handle = null;
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
        private const uint8 COLOR_OPACITY = 204;

        public float monitor_scale { get; construct set; }

        public ActiveShape (float monitor_scale) {
            Object (monitor_scale: monitor_scale);
        }

        construct {
            var rounded_corners_effect = new RoundedCornersEffect (BORDER_RADIUS, monitor_scale);
            bind_property ("monitor-scale", rounded_corners_effect, "monitor-scale");
            add_effect (rounded_corners_effect);

            unowned var style_manager = Drawing.StyleManager.get_instance ();
            style_manager.bind_property ("theme-accent-color", this, "background-color", SYNC_CREATE, (binding, from_value, ref to_value) => {
#if !HAS_MUTTER47
                var new_color = (Clutter.Color) from_value;
#else
                var new_color = (Cogl.Color) from_value;
#endif
                new_color.alpha = COLOR_OPACITY;

                to_value.set_boxed (&new_color);
                return true;
            });
        }
    }
}
