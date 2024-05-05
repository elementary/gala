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
    private struct ChildCloneInfo {
        unowned Clutter.Clone clone;
        unowned Meta.Window window;
    }

    private const int CLOSE_WINDOW_ICON_SIZE = 36;
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

    public WindowManager wm { get; construct; }

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
            active_shape.set_easing_duration (wm.enable_animations ? FADE_ANIMATION_DURATION : 0);
            active_shape.opacity = value ? 255 : 0;
            active_shape.restore_easing_state ();
        }
    }

    public bool overview_mode { get; construct; }
    public GestureTracker? gesture_tracker { get; construct; }
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

    /**
     * Current transition progress. 0 - original state. 1 - slot state.
     */
    public double last_progress_percentage { get; set; default = 0.0; }

    private DragDropAction? drag_action = null;
    private Clutter.Clone? clone = null;
    private ShadowEffect? shadow_effect = null;

    private Clutter.Actor prev_parent = null;
    private int prev_index = -1;
    private bool in_slot_animation = false;

    private Gala.CloseButton close_button;
    private ActiveShape active_shape;
    private Clutter.Actor window_icon;
    private Tooltip window_title;
    private ChildCloneInfo[] child_clone_infos = {};

    public WindowClone (WindowManager wm, Meta.Window window, GestureTracker? gesture_tracker, float scale, bool overview_mode = false) {
        Object (
            wm: wm,
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

        wm.window_created.connect (add_new_window_child);

        if (overview_mode) {
            var click_action = new Clutter.ClickAction ();
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

        window_title = new Tooltip ();
        window_title.opacity = 0;

        active_shape = new ActiveShape ();
        active_shape.opacity = 0;

        add_child (active_shape);
        add_child (window_title);

        reallocate ();

        load_clone ();
    }

    ~WindowClone () {
        window.unmanaged.disconnect (unmanaged);
        window.notify["on-all-workspaces"].disconnect (on_all_workspaces_changed);
        window.notify["fullscreen"].disconnect (check_shadow_requirements);
        window.notify["maximized-horizontally"].disconnect (check_shadow_requirements);
        window.notify["maximized-vertically"].disconnect (check_shadow_requirements);

        wm.window_created.disconnect (add_new_window_child);
    }

    private void reallocate () {
        var window_frame_rect = window.get_frame_rect ();

        close_button = new Gala.CloseButton (monitor_scale_factor) {
            opacity = 0
        };
        close_button.triggered.connect (close_window);

        window_icon = new WindowIcon (window, WINDOW_ICON_SIZE, (int)Math.round (monitor_scale_factor));
        window_icon.opacity = 0;
        window_icon.set_pivot_point (0.5f, 0.5f);
        set_window_icon_position (window_frame_rect.width, window_frame_rect.height, monitor_scale_factor);

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
     *
     * @param was_waiting Internal argument used to indicate that we had to
     *                    wait before the window's texture became available.
     */
    private void load_clone (bool was_waiting = false) {
        var actor = (Meta.WindowActor) window.get_compositor_private ();
        if (actor == null) {
            Idle.add (() => {
                if (window.get_compositor_private () != null)
                    load_clone (true);
                return Source.REMOVE;
            });

            return;
        }

        if (overview_mode) {
            actor.hide ();
        }

        clone = new Clutter.Clone (actor);
        add_child (clone);

        set_child_below_sibling (active_shape, clone);
        set_child_above_sibling (close_button, clone);
        set_child_above_sibling (window_icon, clone);
        set_child_above_sibling (window_title, clone);

        transition_to_original_state (false);

        check_shadow_requirements ();

        if (should_fade ()) {
            opacity = 0;
        }

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

        foreach (unowned var child_window in wm.get_display ().list_all_windows ()) {
            add_new_window_child (child_window);
        }
    }

    private void add_new_window_child (Meta.Window new_window) {
        if (new_window.window_type != MODAL_DIALOG || !(window.is_ancestor_of_transient (new_window) || new_window.find_root_ancestor () == window)) {
            return;
        }

        unowned var new_window_actor = (Meta.WindowActor) new_window.get_compositor_private ();
        if (new_window_actor == null) {
            warning ("New window actor is null");
            return;
        }

        var actor_clone = new Clutter.Clone (new_window_actor);

        var info = ChildCloneInfo () {
            clone = actor_clone,
            window = new_window
        };
        child_clone_infos += info;

        add_child (actor_clone);
        set_child_above_sibling (actor_clone, clone);
        set_child_above_sibling (close_button, actor_clone);
        set_child_above_sibling (window_icon, actor_clone);
        set_child_above_sibling (window_title, actor_clone);
    }

    private void check_shadow_requirements () {
        if (clone == null) {
            return;
        }

        if (window.fullscreen || window.maximized_horizontally && window.maximized_vertically) {
            if (shadow_effect == null) {
                shadow_effect = new ShadowEffect (55) { css_class = "window-clone" };
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
    public void transition_to_original_state (bool animate, bool with_gesture = false, bool is_cancel_animation = false) {
        var outer_rect = window.get_frame_rect ();

        unowned var display = window.get_display ();
        var monitor_geom = display.get_monitor_geometry (window.get_monitor ());
        var initial_scale = monitor_scale_factor;
        var target_scale = display.get_monitor_scale (window.get_monitor ());
        var offset_x = monitor_geom.x;
        var offset_y = monitor_geom.y;

        var initial_x = x;
        var initial_y = y;
        var initial_width = width;
        var initial_height = height;

        var target_x = outer_rect.x - offset_x;
        var target_y = outer_rect.y - offset_y;

        active = false;
        in_slot_animation = true;
        place_widgets (outer_rect.width, outer_rect.height, initial_scale);

        GestureTracker.OnUpdate on_animation_update = (percentage) => {
            var x = GestureTracker.animation_value (initial_x, target_x, percentage);
            var y = GestureTracker.animation_value (initial_y, target_y, percentage);
            var width = GestureTracker.animation_value (initial_width, outer_rect.width, percentage);
            var height = GestureTracker.animation_value (initial_height, outer_rect.height, percentage);
            var scale = GestureTracker.animation_value (initial_scale, target_scale, percentage);
            var opacity = GestureTracker.animation_value (255f, 0f, percentage);

            set_size (width, height);
            set_position (x, y);

            window_icon.opacity = (uint) opacity;
            set_window_icon_position (width, height, scale, false);
            place_widgets ((int)width, (int)height, scale);

            shadow_opacity = (uint8) opacity;
            last_progress_percentage = (1.0 - percentage); // 1.0 means slot position, so reverse the percentage
        };

        GestureTracker.OnEnd on_animation_end = (percentage, cancel_action) => {
            if (cancel_action) {
                return;
            }

            if (!animate || !wm.enable_animations) {
                last_progress_percentage = 0.0; // 0.0 means original state

                set_position (target_x, target_y);
                set_size (outer_rect.width, outer_rect.height);

                if (should_fade ()) {
                    opacity = 0;
                }

                window_icon.opacity = 0;
                set_window_icon_position (outer_rect.width, outer_rect.height, target_scale);

                in_slot_animation = false;
                place_widgets (outer_rect.width, outer_rect.height, target_scale);

                return;
            }

            remove_last_progress_percentage_transition ();
            add_last_progress_transition (0.0);

            save_easing_state ();
            set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            set_easing_duration (MultitaskingView.ANIMATION_DURATION);

            set_position (target_x, target_y);
            set_size (outer_rect.width, outer_rect.height);

            if (should_fade ()) {
                opacity = 0;
            }

            restore_easing_state ();

            toggle_shadow (false);

            window_icon.save_easing_state ();
            window_icon.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            window_icon.set_easing_duration (MultitaskingView.ANIMATION_DURATION);
            window_icon.opacity = 0;
            set_window_icon_position (outer_rect.width, outer_rect.height, target_scale);
            window_icon.restore_easing_state ();

            unowned var transition = window_icon.get_transition ("opacity");
            if (transition == null) {
                critical ("Opacity transition not found");
                return;
            }

            transition.completed.connect (() => {
                in_slot_animation = false;
                place_widgets (outer_rect.width, outer_rect.height, target_scale);
            });
        };

        if (!animate || gesture_tracker == null || !with_gesture || !wm.enable_animations) {
            on_animation_end (1, false, 0);
        } else {
            gesture_tracker.connect_handlers (null, (owned) on_animation_update, (owned) on_animation_end);
        }
    }

    /**
     * Animate the window to the given slot
     */
#if HAS_MUTTER45
    public void take_slot (Mtk.Rectangle rect, bool with_gesture = false, bool is_cancel_animation = false) {
#else
    public void take_slot (Meta.Rectangle rect, bool with_gesture = false, bool is_cancel_animation = false) {
#endif
        slot = rect;
        var initial_x = x;
        var initial_y = y;
        var initial_width = width;
        var initial_height = height;

        active = false;
        unowned var display = wm.get_display ();
        var scale = display.get_monitor_scale (display.get_monitor_index_for_rect (rect));

        in_slot_animation = true;
        place_widgets (rect.width, rect.height, scale);

        GestureTracker.OnUpdate on_animation_update = (percentage) => {
            var x = GestureTracker.animation_value (initial_x, rect.x, percentage);
            var y = GestureTracker.animation_value (initial_y, rect.y, percentage);
            var width = GestureTracker.animation_value (initial_width, rect.width, percentage);
            var height = GestureTracker.animation_value (initial_height, rect.height, percentage);
            var opacity = GestureTracker.animation_value (0f, 255f, percentage);

            set_size (width, height);
            set_position (x, y);

            window_icon.opacity = (uint) opacity;
            set_window_icon_position (width, height, scale, false);

            shadow_opacity = (uint8) opacity;
            last_progress_percentage = percentage;
        };

        GestureTracker.OnEnd on_animation_end = (percentage, cancel_action) => {
            if (cancel_action) {
                return;
            }

            toggle_shadow (true);

            if (!wm.enable_animations) {
                last_progress_percentage = 1.0;
                opacity = 255;
                window_icon.opacity = 255;
                set_window_icon_position (rect.width, rect.height, scale);

                in_slot_animation = false;
                place_widgets (rect.width, rect.height, scale);

                return;
            }

            remove_last_progress_percentage_transition ();
            add_last_progress_transition (1.0);

            save_easing_state ();
            set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            set_easing_duration (MultitaskingView.ANIMATION_DURATION);
            set_size (rect.width, rect.height);
            set_position (rect.x, rect.y);
            opacity = 255;
            restore_easing_state ();

            window_icon.save_easing_state ();
            window_icon.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            window_icon.set_easing_duration (MultitaskingView.ANIMATION_DURATION);
            window_icon.opacity = 255;
            set_window_icon_position (rect.width, rect.height, scale);
            window_icon.restore_easing_state ();

            unowned var transition = window_icon.get_transition ("opacity");
            if (transition == null) {
                critical ("Opacity transition not found");
                return;
            }

            transition.completed.connect (() => {
                in_slot_animation = false;
                place_widgets (rect.width, rect.height, scale);
            });
        };

        if (gesture_tracker == null || !with_gesture || !wm.enable_animations) {
            on_animation_end (1, false, 0);
        } else {
            gesture_tracker.connect_handlers (null, (owned) on_animation_update, (owned) on_animation_end);
        }
    }

    private void remove_last_progress_percentage_transition () {
        remove_transition ("last_progress_percentage");
    }

    private void add_last_progress_transition (double target_value) {
        var progress_transition = new Clutter.PropertyTransition ("last_progress_percentage") {
            duration = MultitaskingView.ANIMATION_DURATION,
            progress_mode = Clutter.AnimationMode.EASE_OUT_QUAD,
            remove_on_complete = true
        };
        progress_transition.set_from_value (last_progress_percentage);
        progress_transition.set_to_value (target_value);
        add_transition ("last_progress_percentage", progress_transition);
    }

    /**
     * Except for the texture clone and the highlight all children are placed
     * according to their given allocations. The first two are placed in a way
     * that compensates for invisible borders of the texture.
     */
    public override void allocate (Clutter.ActorBox box) {
        base.allocate (box);

        var input_rect = window.get_buffer_rect ();
        var outer_rect = window.get_frame_rect ();
        var scale_factor = width / outer_rect.width;

        Clutter.ActorBox shape_alloc = {
            -ACTIVE_SHAPE_SIZE,
            -ACTIVE_SHAPE_SIZE,
            outer_rect.width * scale_factor + ACTIVE_SHAPE_SIZE,
            outer_rect.height * scale_factor + ACTIVE_SHAPE_SIZE
        };
        active_shape.allocate (shape_alloc);

        foreach (var child_info in child_clone_infos) {
            child_info.clone.set_scale (scale_factor, scale_factor);

            var child_input_rect = child_info.window.get_buffer_rect ();
            var child_outer_rect = child_info.window.get_frame_rect ();

            var child_shadow_offset_x = child_input_rect.x - child_outer_rect.x;
            var child_shadow_offset_y = child_input_rect.y - child_outer_rect.y;

            // outer rects are used because they doesn't include shadows
            // calculate real overlay diff
            var child_parent_x_diff = child_outer_rect.x - outer_rect.x;
            var child_parent_y_diff = child_outer_rect.y - outer_rect.y;

            var source_x = (child_shadow_offset_x + child_parent_x_diff) * scale_factor;
            var source_y = (child_shadow_offset_y + child_parent_y_diff) * scale_factor;

            var target_calculated_x = source_x.clamp (
                (child_input_rect.x - child_outer_rect.x) * scale_factor,
                (child_input_rect.x - child_outer_rect.x + outer_rect.width - child_outer_rect.width) * scale_factor
            );
            var target_calculated_y = source_y.clamp (
                (child_input_rect.y - child_outer_rect.y) * scale_factor,
                (child_input_rect.y - child_outer_rect.y + outer_rect.height - child_outer_rect.height) * scale_factor
            );

            var calculated_x = GestureTracker.animation_value (
                source_x,
                target_calculated_x,
                last_progress_percentage,
                last_progress_percentage % 1 == 0
            );
            var calculated_y = GestureTracker.animation_value (
                source_y,
                target_calculated_y,
                last_progress_percentage,
                last_progress_percentage % 1 == 0
            );

            child_info.clone.set_position (calculated_x, calculated_y);
        }

        if (clone == null || (drag_action != null && drag_action.dragging)) {
            return;
        }

        clone.set_scale (scale_factor, scale_factor);
        clone.set_position (
            (input_rect.x - outer_rect.x) * scale_factor,
            (input_rect.y - outer_rect.y) * scale_factor
        );
    }

#if HAS_MUTTER45
    public override bool button_press_event (Clutter.Event event) {
#else
    public override bool button_press_event (Clutter.ButtonEvent event) {
#endif
        return Clutter.EVENT_STOP;
    }

#if HAS_MUTTER45
    public override bool enter_event (Clutter.Event event) {
#else
    public override bool enter_event (Clutter.CrossingEvent event) {
#endif
        if (drag_action != null && drag_action.dragging) {
            return Clutter.EVENT_PROPAGATE;
        }

        var duration = wm.enable_animations ? FADE_ANIMATION_DURATION : 0;

        close_button.save_easing_state ();
        close_button.set_easing_mode (Clutter.AnimationMode.LINEAR);
        close_button.set_easing_duration (duration);
        close_button.opacity = in_slot_animation ? 0 : 255;
        close_button.restore_easing_state ();

        window_title.save_easing_state ();
        window_title.set_easing_mode (Clutter.AnimationMode.LINEAR);
        window_title.set_easing_duration (duration);
        window_title.opacity = in_slot_animation ? 0 : 255;
        window_title.restore_easing_state ();

        return Clutter.EVENT_PROPAGATE;
    }

#if HAS_MUTTER45
    public override bool leave_event (Clutter.Event event) {
#else
    public override bool leave_event (Clutter.CrossingEvent event) {
#endif
        var duration = wm.enable_animations ? FADE_ANIMATION_DURATION : 0;

        close_button.save_easing_state ();
        close_button.set_easing_mode (Clutter.AnimationMode.LINEAR);
        close_button.set_easing_duration (duration);
        close_button.opacity = 0;
        close_button.restore_easing_state ();

        window_title.save_easing_state ();
        window_title.set_easing_mode (Clutter.AnimationMode.LINEAR);
        window_title.set_easing_duration (duration);
        window_title.opacity = 0;
        window_title.restore_easing_state ();

        return Clutter.EVENT_PROPAGATE;
    }

    /**
     * Place the widgets, that is the close button and the WindowIcon of the window,
     * at their positions inside the actor for a given width and height.
     */
    public void place_widgets (int dest_width, int dest_height, float scale_factor) {
        var close_button_size = InternalUtils.scale_to_int (CLOSE_WINDOW_ICON_SIZE, scale_factor);
        close_button.set_size (close_button_size, close_button_size);

        close_button.y = -close_button.height * 0.33f;
        close_button.x = is_close_button_on_left () ?
            -close_button.width * 0.5f :
            dest_width - close_button.width * 0.5f;

        bool show = has_pointer && !in_slot_animation;
        close_button.opacity = show ? 255 : 0;
        window_title.opacity = close_button.opacity;

        window_title.set_text (window.get_title () ?? "");
        window_title.set_max_width (dest_width - InternalUtils.scale_to_int (TITLE_MAX_WIDTH_MARGIN, scale_factor));
        set_window_title_position (dest_width, dest_height, scale_factor);
    }

    private void toggle_shadow (bool show) {
        if (get_transition ("shadow-opacity") != null) {
            remove_transition ("shadow-opacity");
        }

        if (wm.enable_animations) {
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

    private void close_window (uint32 timestamp) {
        window.@delete (timestamp);
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

        destroy ();
    }

    private void actor_clicked (uint32 button) {
        switch (button) {
            case Clutter.Button.PRIMARY:
                selected ();
                break;
            case Clutter.Button.MIDDLE:
                close_window (wm.get_display ().get_current_time ());
                break;
        }
    }

    /**
     * A drag action has been initiated on us, we reparent ourselves to the stage so
     * we can move freely, scale ourselves to a smaller scale and request that the
     * position we just freed is immediately filled by the WindowCloneContainer.
     */
    private Clutter.Actor drag_begin (float click_x, float click_y) {
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
        var duration = wm.enable_animations ? FADE_ANIMATION_DURATION : 0;

        clone.get_transformed_position (out abs_x, out abs_y);
        clone.save_easing_state ();
        clone.set_easing_duration (duration);
        clone.set_easing_mode (Clutter.AnimationMode.EASE_IN_CUBIC);
        clone.set_pivot_point ((click_x - abs_x) / clone.width, (click_y - abs_y) / clone.height);
        clone.set_scale (scale, scale);
        clone.opacity = 0;
        clone.restore_easing_state ();

        foreach (var child_clone_info in child_clone_infos) {
            unowned var child_actor = child_clone_info.clone;
            child_actor.get_transformed_position (out abs_x, out abs_y);
            child_actor.save_easing_state ();
            child_actor.set_easing_duration (duration);
            child_actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_CUBIC);
            child_actor.set_pivot_point ((click_x - abs_x) / child_actor.width, (click_y - abs_y) / child_actor.height);
            child_actor.set_scale (scale, scale);
            child_actor.opacity = 0;
            child_actor.restore_easing_state ();
        }

        request_reposition ();

        get_transformed_position (out abs_x, out abs_y);

        set_position (abs_x + prev_parent_x, abs_y + prev_parent_y);

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

        wm.get_display ().set_cursor (Meta.Cursor.DND_IN_DRAG);

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
        var duration = hovered && insert_thumb != null ? insert_thumb.delay : 100;
        duration = wm.enable_animations ? duration : 0;

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

        wm.get_display ().set_cursor (hovered ? Meta.Cursor.DND_MOVE: Meta.Cursor.DND_IN_DRAG);
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

        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);

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
        prev_parent.insert_child_at_index (this, prev_index);

        var duration = wm.enable_animations ? MultitaskingView.ANIMATION_DURATION : 0;

        clone.set_pivot_point (0.0f, 0.0f);
        clone.save_easing_state ();
        clone.set_easing_duration (duration);
        clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        clone.set_scale (1, 1);
        clone.opacity = 255;
        clone.restore_easing_state ();

        foreach (var child_clone_info in child_clone_infos) {
            unowned var child_clone = child_clone_info.clone;
            child_clone.set_pivot_point (0.0f, 0.0f);
            child_clone.save_easing_state ();
            child_clone.set_easing_duration (duration);
            child_clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            child_clone.set_scale (1, 1);
            child_clone.opacity = 255;
            child_clone.restore_easing_state ();
        }

        request_reposition ();

        window_icon.save_easing_state ();
        window_icon.set_easing_duration (duration);
        window_icon.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);

        set_window_icon_position (slot.width, slot.height, monitor_scale_factor);
        window_icon.restore_easing_state ();

        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);
    }

    private void set_window_icon_position (float window_width, float window_height, float scale_factor, bool aligned = true) {
        var size = InternalUtils.scale_to_int (WINDOW_ICON_SIZE, scale_factor);
        var x = (window_width - size) / 2;
        var y = window_height - (size * 0.75f);

        if (aligned) {
            x = (int) Math.round (x);
            y = (int) Math.round (y);
        }

        window_icon.set_size (size, size);
        window_icon.set_position (x, y);
    }

    private void set_window_title_position (float window_width, float window_height, float scale_factor) {
        var x = (int)Math.round ((window_width - window_title.width) / 2);
        var y = (int)Math.round (window_height - InternalUtils.scale_to_int (WINDOW_ICON_SIZE, scale_factor) * 0.75f - (window_title.height / 2) - InternalUtils.scale_to_int (18, scale_factor));
        window_title.set_position (x, y);
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
