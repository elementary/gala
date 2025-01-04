/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022-2023 elementary, Inc. (https://elementary.io)
 *                         2014 Tom Beckmann
 */

/**
 * A container for a clone of the texture of a MetaWindow, a WindowIcon, a Tooltip with the title,
 * a close button and a shadow. Used together with the WindowCloneContainer.
 */
public class Gala.WindowClone : Clutter.Actor {
    private const int WINDOW_ICON_SIZE = 64;
    private const int ACTIVE_SHAPE_SIZE = 12;
    private const int FADE_ANIMATION_DURATION = 200;
    private const int TITLE_MAX_WIDTH_MARGIN = 60;

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

    public Meta.Display display { get; construct; }

    public Meta.Window window { get; construct; }

    /**
     * The currently assigned slot of the window in the tiling layout. May be null.
     */
#if HAS_MUTTER45
    public Mtk.Rectangle? slot { get; private set; default = null; }
#else
    public Meta.Rectangle? slot { get; private set; default = null; }
#endif

    /**
     * When active fades a white border around the window in. Used for the visually
     * indicating the WindowCloneContainer's current_window.
     */
    public bool active {
        set {
            active_shape.save_easing_state ();
            active_shape.set_easing_duration (AnimationsSettings.get_animation_duration (FADE_ANIMATION_DURATION));
            active_shape.opacity = value ? 255 : 0;
            active_shape.restore_easing_state ();
        }
    }

    public bool overview_mode { get; construct; }
    public GestureTracker gesture_tracker { get; construct; }
    private float _monitor_scale_factor = 1.0f;
    public float monitor_scale_factor {
        get {
            return _monitor_scale_factor;
        }
        set {
            if (value != _monitor_scale_factor) {
                _monitor_scale_factor = value;
                reallocate ();
            }
        }
    }

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

    private Clutter.Actor prev_parent = null;
    private int prev_index = -1;
    private ulong check_confirm_dialog_cb = 0;
    private bool in_slot_animation = false;

    private Gala.CloseButton close_button;
    private ActiveShape active_shape;
    private Clutter.Actor window_icon;
    private Tooltip window_title;

    public WindowClone (Meta.Display display, Meta.Window window, GestureTracker gesture_tracker, float scale, bool overview_mode = false) {
        Object (
            display: display,
            window: window,
            gesture_tracker: gesture_tracker,
            monitor_scale_factor: scale,
            overview_mode: overview_mode
        );
    }

    construct {
        reactive = true;

        window.unmanaged.connect (unmanaged);
        window.notify["on-all-workspaces"].connect (on_all_workspaces_changed);
        window.notify["fullscreen"].connect (check_shadow_requirements);
        window.notify["maximized-horizontally"].connect (check_shadow_requirements);
        window.notify["maximized-vertically"].connect (check_shadow_requirements);
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
            drag_action.destination_crossed.connect (drag_destination_crossed);
            drag_action.drag_end.connect (drag_end);
            drag_action.drag_canceled.connect (drag_canceled);
            drag_action.actor_clicked.connect (actor_clicked);

            add_action (drag_action);
        }

        window_title = new Tooltip ();
        window_title.opacity = 0;

        active_shape = new ActiveShape ();
        active_shape.opacity = 0;

        add_child (active_shape);
        add_child (window_title);

        reallocate ();

        InternalUtils.wait_for_window_actor (window, load_clone);

        window.notify["title"].connect (() => window_title.set_text (window.get_title () ?? ""));
        window_title.set_text (window.get_title () ?? "");

        notify["has-pointer"].connect (() => update_hover_widgets ());
    }

    ~WindowClone () {
        window.unmanaged.disconnect (unmanaged);
        window.notify["on-all-workspaces"].disconnect (on_all_workspaces_changed);
        window.notify["fullscreen"].disconnect (check_shadow_requirements);
        window.notify["maximized-horizontally"].disconnect (check_shadow_requirements);
        window.notify["maximized-vertically"].disconnect (check_shadow_requirements);
    }

    private void reallocate () {
        close_button = new Gala.CloseButton (monitor_scale_factor) {
            opacity = 0
        };
        close_button.triggered.connect (close_window);

        window_icon = new WindowIcon (window, WINDOW_ICON_SIZE, (int)Math.round (monitor_scale_factor)) {
            visible = !overview_mode
        };
        window_icon.opacity = 0;
        window_icon.set_pivot_point (0.5f, 0.5f);

        add_child (close_button);
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
        if (overview_mode) {
            actor.hide ();
        }

        clone = new Clutter.Clone (actor);
        clone.set_content_scaling_filters (TRILINEAR, TRILINEAR);
        add_child (clone);

        set_child_below_sibling (active_shape, clone);
        set_child_above_sibling (close_button, clone);
        set_child_above_sibling (window_icon, clone);
        set_child_above_sibling (window_title, clone);

        check_shadow_requirements ();

        if (should_fade ()) {
            opacity = 0;
        }
    }

    private void check_shadow_requirements () {
        if (clone == null) {
            return;
        }

        if (window.fullscreen || window.maximized_horizontally && window.maximized_vertically) {
            if (shadow_effect == null) {
                shadow_effect = new ShadowEffect ("window");
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

    private void on_all_workspaces_changed () {
        // we don't display windows that are on all workspaces
        if (window.on_all_workspaces) {
            unmanaged ();
        }
    }

    /**
     * Place the window at the location of the original MetaWindow
     *
     * @param animate Animate the transformation of the placement
     */
    public void transition_to_original_state (bool with_gesture = false) {
        var outer_rect = window.get_frame_rect ();

        unowned var display = window.get_display ();
        var monitor_geom = display.get_monitor_geometry (window.get_monitor ());

        var target_x = outer_rect.x - monitor_geom.x;
        var target_y = outer_rect.y - monitor_geom.y;

        active = false;
        update_hover_widgets (true);

        new GesturePropertyTransition (this, gesture_tracker, "x", null, (float) target_x).start (with_gesture);
        new GesturePropertyTransition (this, gesture_tracker, "y", null, (float) target_y).start (with_gesture);
        new GesturePropertyTransition (this, gesture_tracker, "width", null, (float) outer_rect.width).start (with_gesture);
        new GesturePropertyTransition (this, gesture_tracker, "height", null, (float) outer_rect.height).start (with_gesture);
        new GesturePropertyTransition (this, gesture_tracker, "shadow-opacity", (uint8) 255, (uint8) 0).start (with_gesture);
        new GesturePropertyTransition (window_icon, gesture_tracker, "opacity", 255u, 0u).start (with_gesture, () => {
            update_hover_widgets (false);
            toggle_shadow (false);
        });

        if (should_fade ()) {
            new GesturePropertyTransition (this, gesture_tracker, "opacity", null, 0u).start (with_gesture);
        }
    }

    /**
     * Animate the window to the given slot
     */
#if HAS_MUTTER45
    public void take_slot (Mtk.Rectangle rect, bool from_window_position, bool with_gesture = false) {
#else
    public void take_slot (Meta.Rectangle rect, bool from_window_position, bool with_gesture = false) {
#endif
        slot = rect;
        active = false;

        var outer_rect = window.get_frame_rect ();

        float initial_width = from_window_position ? outer_rect.width : width;
        float initial_height = from_window_position ? outer_rect.height : height;

        var monitor_geom = display.get_monitor_geometry (window.get_monitor ());
        float intial_x = from_window_position ? outer_rect.x - monitor_geom.x : x;
        float intial_y = from_window_position ? outer_rect.y - monitor_geom.y : y;

        update_hover_widgets (true);

        new GesturePropertyTransition (this, gesture_tracker, "x", intial_x, (float) rect.x).start (with_gesture);
        new GesturePropertyTransition (this, gesture_tracker, "y", intial_y, (float) rect.y).start (with_gesture);
        new GesturePropertyTransition (this, gesture_tracker, "width", (float) initial_width, (float) rect.width).start (with_gesture);
        new GesturePropertyTransition (this, gesture_tracker, "height", (float) initial_height, (float) rect.height).start (with_gesture);
        new GesturePropertyTransition (this, gesture_tracker, "opacity", null, 255u).start (with_gesture);
        new GesturePropertyTransition (this, gesture_tracker, "shadow-opacity", (uint8) 0, (uint8) 255).start (with_gesture);
        new GesturePropertyTransition (window_icon, gesture_tracker, "opacity", 0u, 255u).start (with_gesture, () => {
            update_hover_widgets (false);
            toggle_shadow (true);
        });
    }

    public override void allocate (Clutter.ActorBox box) {
        base.allocate (box);

        if (clone == null || (drag_action != null && drag_action.dragging)) {
            return;
        }

        var input_rect = window.get_buffer_rect ();
        var outer_rect = window.get_frame_rect ();
        var clone_scale_factor = width / outer_rect.width;

        clone.set_scale (clone_scale_factor, clone_scale_factor);

        float clone_width, clone_height;
        clone.get_preferred_size (null, null, out clone_width, out clone_height);

        // Compensate for invisible borders of the texture
        float clone_x = (input_rect.x - outer_rect.x) * clone_scale_factor;
        float clone_y = (input_rect.y - outer_rect.y) * clone_scale_factor;

        var clone_alloc = InternalUtils.actor_box_from_rect (clone_x, clone_y, clone_width, clone_height);
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

        float window_title_max_width = box.get_width () - InternalUtils.scale_to_int (TITLE_MAX_WIDTH_MARGIN, monitor_scale);
        float window_title_height, window_title_nat_width;
        window_title.get_preferred_size (null, null, out window_title_nat_width, out window_title_height);

        var window_title_width = window_title_nat_width.clamp (0, window_title_max_width);

        float window_title_x = (box.get_width () - window_title_width) / 2;
        float window_title_y = (window_icon.visible ? window_icon_y : box.get_height ()) - (window_title_height / 2) - InternalUtils.scale_to_int (18, monitor_scale);

        var window_title_alloc = InternalUtils.actor_box_from_rect (window_title_x, window_title_y, window_title_width, window_title_height);
        window_title.allocate (window_title_alloc);
    }

#if HAS_MUTTER45
    public override bool button_press_event (Clutter.Event event) {
#else
    public override bool button_press_event (Clutter.ButtonEvent event) {
#endif
        return Clutter.EVENT_STOP;
    }

    private void update_hover_widgets (bool? animating = null) {
        if (animating != null) {
            in_slot_animation = animating;
        }

        var duration = AnimationsSettings.get_animation_duration (FADE_ANIMATION_DURATION);

        var show = has_pointer && !in_slot_animation;

        close_button.save_easing_state ();
        close_button.set_easing_mode (Clutter.AnimationMode.LINEAR);
        close_button.set_easing_duration (duration);
        close_button.opacity = show ? 255 : 0;
        close_button.restore_easing_state ();

        window_title.save_easing_state ();
        window_title.set_easing_mode (Clutter.AnimationMode.LINEAR);
        window_title.set_easing_duration (duration);
        window_title.opacity = show ? 255 : 0;
        window_title.restore_easing_state ();
    }

    private void toggle_shadow (bool show) {
        if (get_transition ("shadow-opacity") != null) {
            remove_transition ("shadow-opacity");
        }

        if (AnimationsSettings.get_enable_animations ()) {
            var shadow_transition = new Clutter.PropertyTransition ("shadow-opacity") {
                duration = MultitaskingView.ANIMATION_DURATION,
                remove_on_complete = true,
                progress_mode = Clutter.AnimationMode.EASE_OUT_QUAD,
                interval = new Clutter.Interval (typeof (uint8), shadow_opacity, show ? 255 : 0)
            };

            add_transition ("shadow-opacity", shadow_transition);
        } else {
            shadow_opacity = show ? 255 : 0;
        }
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
        if (new_window.get_transient_for () == window) {
            Idle.add (() => {
                selected ();
                return Source.REMOVE;
            });

            SignalHandler.disconnect (window.get_display (), check_confirm_dialog_cb);
            check_confirm_dialog_cb = 0;
        }
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

        destroy ();
    }

    private void actor_clicked (uint32 button) {
        switch (button) {
            case Clutter.Button.PRIMARY:
                selected ();
                break;
            case Clutter.Button.MIDDLE:
                close_window (display.get_current_time ());
                break;
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

        var scale = window_icon.width / clone.width;
        var duration = AnimationsSettings.get_animation_duration (FADE_ANIMATION_DURATION);

        clone.get_transformed_position (out abs_x, out abs_y);
        clone.save_easing_state ();
        clone.set_easing_duration (duration);
        clone.set_easing_mode (Clutter.AnimationMode.EASE_IN_CUBIC);
        clone.set_pivot_point ((click_x - abs_x) / clone.width, (click_y - abs_y) / clone.height);
        clone.set_scale (scale, scale);
        clone.opacity = 0;
        clone.restore_easing_state ();

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

        display.set_cursor (Meta.Cursor.DND_IN_DRAG);

        return this;
    }

    /**
     * When we cross an IconGroup, we animate to an even smaller size and slightly
     * less opacity and add ourselves as temporary window to the group. When left,
     * we reverse those steps.
     */
    private void drag_destination_crossed (Clutter.Actor destination, bool hovered) {
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
        duration = AnimationsSettings.get_animation_duration (duration);

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

        display.set_cursor (hovered ? Meta.Cursor.DND_MOVE: Meta.Cursor.DND_IN_DRAG);
    }

    /**
     * Depending on the destination we have different ways to find the correct destination.
     * After we found one we destroy ourselves so the dragged clone immediately disappears,
     * otherwise we cancel the drag and animate back to our old place.
     */
    private void drag_end (Clutter.Actor destination) {
        Meta.Workspace workspace = null;
        var primary = window.get_display ().get_primary_monitor ();

        active_shape.show ();

        display.set_cursor (Meta.Cursor.DEFAULT);

        if (destination is IconGroup) {
            workspace = ((IconGroup) destination).workspace;
        } else if (destination is FramedBackground) {
            workspace = ((WorkspaceClone) destination.get_parent ()).workspace;
        } else if (destination is WorkspaceInsertThumb) {
            if (!Meta.Prefs.get_dynamic_workspaces ()) {
                drag_canceled ();
                return;
            }

            unowned WorkspaceInsertThumb inserter = (WorkspaceInsertThumb) destination;

            var will_move = window.get_workspace ().index () != inserter.workspace_index;

            if (Meta.Prefs.get_workspaces_only_on_primary () && !window.is_on_primary_monitor ()) {
                window.move_to_monitor (primary);
                will_move = true;
            }

            InternalUtils.insert_workspace_with_window (inserter.workspace_index, window);

            // if we don't actually change workspaces, the window-added/removed signals won't
            // be emitted so we can just keep our window here
            if (will_move) {
                unmanaged ();
            } else {
                drag_canceled ();
            }

            return;
        } else if (destination is MonitorClone) {
            var monitor = ((MonitorClone) destination).monitor;
            if (window.get_monitor () != monitor) {
                window.move_to_monitor (monitor);
                unmanaged ();
            } else {
                drag_canceled ();
            }

            return;
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
        prev_parent.add_child (this); // Add above so that it is above while it animates back to its place

        var duration = AnimationsSettings.get_animation_duration (MultitaskingView.ANIMATION_DURATION);

        clone.set_pivot_point (0.0f, 0.0f);
        clone.save_easing_state ();
        clone.set_easing_duration (duration);
        clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        clone.set_scale (1, 1);
        clone.opacity = 255;
        clone.restore_easing_state ();

        request_reposition ();

        display.set_cursor (Meta.Cursor.DEFAULT);

        if (duration > 0) {
            ulong handler = 0;
            handler = clone.transitions_completed.connect (() => {
                prev_parent.set_child_at_index (this, prev_index); // Set the correct index so that correct stacking order is kept
                clone.disconnect (handler);
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
    private class ActiveShape : CanvasActor {
        private const int BORDER_RADIUS = 16;
        private const double COLOR_OPACITY = 0.8;

        construct {
            notify["opacity"].connect (invalidate);
        }

        public void invalidate () {
            content.invalidate ();
        }

        protected override void draw (Cairo.Context cr, int width, int height) {
            if (!visible || opacity == 0) {
                return;
            }

            var color = Drawing.StyleManager.get_instance ().theme_accent_color;

            cr.save ();
            cr.set_operator (Cairo.Operator.CLEAR);
            cr.paint ();
            cr.restore ();

            Drawing.Utilities.cairo_rounded_rectangle (cr, 0, 0, width, height, BORDER_RADIUS);
            cr.set_source_rgba (color.red, color.green, color.blue, COLOR_OPACITY);
            cr.fill ();
        }
    }
}
