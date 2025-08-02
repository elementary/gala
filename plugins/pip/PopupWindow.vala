/*
 * Copyright 2017 Adam Bieńkowski
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Plugins.PIP.PopupWindow : RootTarget, ActorTarget {
    private int button_size;
    private int container_margin;
    private const uint FADE_OUT_TIMEOUT = 200;
    private const float MINIMUM_SCALE = 0.1f;
    private const float MAXIMUM_SCALE = 1.0f;
    private const int SCREEN_MARGIN = 0;
    private const float OFF_SCREEN_PERCENT = 0.5f;
    private const int OFF_SCREEN_VISIBLE_PIXELS = 80;

    public signal void closed ();

    public WindowManager wm { get; construct; }
    public Meta.WindowActor window_actor { get; construct; }

    private Clutter.Clone clone; // clone itself
    private Clutter.Actor clone_container; // clips the clone
    private Clutter.Actor rounded_container; // draws rounded corners
    private Clutter.Actor container; // draws the shadow
    private Gala.CloseButton close_button;
    private Clutter.Actor resize_button;
    private DragDropAction move_action;

    private GestureController gesture_controller;
    private PropertyTarget opacity_target;
    private double custom_progress = 0.0;
    private double multitasking_view_progress = 0.0;

    private float begin_resize_width = 0.0f;
    private float begin_resize_height = 0.0f;
    private float resize_start_x = 0.0f;
    private float resize_start_y = 0.0f;

    private bool resizing = false;
    private bool off_screen = false;
    private Clutter.Grab? grab = null;

    private static unowned Meta.Window? previous_focus = null;

    // From https://opensourcehacker.com/2011/12/01/calculate-aspect-ratio-conserving-resize-for-images-in-javascript/
    private static void calculate_aspect_ratio_size_fit (float src_width, float src_height, float max_width, float max_height,
        out float width, out float height) {
        float ratio = float.min (max_width / src_width, max_height / src_height);
        width = src_width * ratio;
        height = src_height * ratio;
    }

    public PopupWindow (WindowManager wm, Meta.WindowActor window_actor) {
        Object (wm: wm, window_actor: window_actor);
    }

    construct {
        unowned var display = wm.get_display ();

        var scale = display.get_monitor_scale (display.get_current_monitor ());

        button_size = Gala.Utils.scale_to_int (36, scale);
        container_margin = button_size / 2;

        reactive = true;
        set_pivot_point (0.5f, 0.5f);
        set_easing_mode (Clutter.AnimationMode.EASE_IN_QUAD);

        clone = new Clutter.Clone (window_actor);

        clone_container = new Clutter.Actor () {
            scale_x = 0.35f,
            scale_y = 0.35f
        };
        clone_container.add_child (clone);

        rounded_container = new Clutter.Actor ();
        rounded_container.add_child (clone_container);
        rounded_container.add_effect (new RoundedCornersEffect (6, scale));

        container = new Clutter.Actor ();
        container.add_child (rounded_container);
        container.add_effect (new ShadowEffect ("window", scale));

        move_action = new DragDropAction (DragDropActionType.SOURCE, "pip");
        move_action.drag_begin.connect (on_move_begin);
        move_action.drag_canceled.connect (on_move_end);
        move_action.actor_clicked.connect (activate);
        add_action (move_action);

        update_size ();

        var workarea_rect = display.get_workspace_manager ().get_active_workspace ().get_work_area_all_monitors ();

        float x_position, y_position;
        if (Clutter.get_default_text_direction () == Clutter.TextDirection.RTL) {
            x_position = SCREEN_MARGIN + workarea_rect.x;
        } else {
            x_position = workarea_rect.x + workarea_rect.width - SCREEN_MARGIN - width;
        }
        y_position = workarea_rect.y + workarea_rect.height - SCREEN_MARGIN - height;

        set_position (x_position, y_position);

        close_button = new Gala.CloseButton (scale) {
            opacity = 0
        };
        // TODO: Check if close button should be on the right
        close_button.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.X_AXIS, 0.0f));
        close_button.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.Y_AXIS, 0.0f));
        close_button.triggered.connect (on_close_click_clicked);

        resize_button = Utils.create_resize_button (scale);
        resize_button.opacity = 0;
        resize_button.reactive = true;
        resize_button.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.X_AXIS, 1.0f));
        resize_button.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.Y_AXIS, 1.0f));
        resize_button.button_press_event.connect (on_resize_button_press);

        add_child (container);
        add_child (close_button);
        add_child (resize_button);

        window_actor.notify["allocation"].connect (on_allocation_changed);
        container.set_position (container_margin, container_margin);
        on_allocation_changed ();

        unowned var window = window_actor.get_meta_window ();
        window.unmanaged.connect (on_close_click_clicked);
        window.notify["appears-focused"].connect (update_window_focus);

        unowned var workspace_manager = display.get_workspace_manager ();
        workspace_manager.active_workspace_changed.connect (update_window_focus);

        gesture_controller = new GestureController (CUSTOM, wm);
        add_gesture_controller (gesture_controller);

        opacity_target = new PropertyTarget (CUSTOM, this, "opacity", typeof (uint), 255u, 0u);
        add_target (opacity_target);

        wm.add_multitasking_view_target (this);
    }

    private double get_opacity_progress () {
        return double.max (custom_progress, multitasking_view_progress);
    }

    public override void start_progress (GestureAction action) {
        if (action != CUSTOM && action != MULTITASKING_VIEW) {
            return;
        }

        move_action.cancel ();
        stop_resizing ();
        hide_buttons ();
        reactive = false;
    }

    public override void end_progress (GestureAction action) {
        if (action != CUSTOM && action != MULTITASKING_VIEW) {
            return;
        }

        reactive = get_current_progress (CUSTOM) == 0.0 && get_current_progress (MULTITASKING_VIEW) == 0.0;
    }

    public override void update_progress (GestureAction action, double progress) {
        switch (action) {
            case MULTITASKING_VIEW:
                multitasking_view_progress = progress;
                break;

            case CUSTOM:
                custom_progress = progress;
                break;

            default:
                break;
        }

        opacity_target.propagate (UPDATE, CUSTOM, get_opacity_progress ());
    }

    public override bool enter_event (Clutter.Event event) {
        var duration = Utils.get_animation_duration (300);

        close_button.save_easing_state ();
        close_button.set_easing_duration (duration);
        close_button.opacity = 255;
        close_button.restore_easing_state ();

        resize_button.save_easing_state ();
        resize_button.set_easing_duration (duration);
        resize_button.opacity = 255;
        resize_button.restore_easing_state ();

        return Clutter.EVENT_PROPAGATE;
    }

    public override bool leave_event (Clutter.Event event) {
        hide_buttons ();
        return Clutter.EVENT_PROPAGATE;
    }

    private void hide_buttons () {
        var duration = Utils.get_animation_duration (300);

        close_button.save_easing_state ();
        close_button.set_easing_duration (duration);
        close_button.opacity = 0;
        close_button.restore_easing_state ();

        resize_button.save_easing_state ();
        resize_button.set_easing_duration (duration);
        resize_button.opacity = 0;
        resize_button.restore_easing_state ();
    }

    public void set_container_clip (Graphene.Rect? container_clip) {
        clone_container.clip_rect = container_clip;
        update_clone_container_scale ();
        on_allocation_changed ();
    }

    private Clutter.Actor on_move_begin () {
#if HAS_MUTTER48
        wm.get_display ().set_cursor (Meta.Cursor.MOVE);
#else
        wm.get_display ().set_cursor (Meta.Cursor.DND_IN_DRAG);
#endif

        return this;
    }

    private void on_move_end () {
        update_screen_position ();
        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);
    }

    private bool on_resize_button_press (Clutter.Event event) {
        if (resizing || event.get_button () != Clutter.Button.PRIMARY) {
            return Clutter.EVENT_STOP;
        }

        resizing = true;

        event.get_coords (out resize_start_x, out resize_start_y);

        begin_resize_width = width;
        begin_resize_height = height;

        grab = resize_button.get_stage ().grab (resize_button);
        resize_button.event.connect (on_resize_event);

        wm.get_display ().set_cursor (Meta.Cursor.SE_RESIZE);

        return Clutter.EVENT_PROPAGATE;
    }

    private bool on_resize_event (Clutter.Event event) {
        if (!resizing) {
            return Clutter.EVENT_STOP;
        }

        switch (event.get_type ()) {
            case Clutter.EventType.MOTION:
                var mods = event.get_state ();
                if (!(Clutter.ModifierType.BUTTON1_MASK in mods)) {
                    stop_resizing ();
                    break;
                }

                float event_x, event_y;
                event.get_coords (out event_x, out event_y);
                float diff_x = event_x - resize_start_x;
                float diff_y = event_y - resize_start_y;

                width = begin_resize_width + diff_x;
                height = begin_resize_height + diff_y;

                update_clone_container_scale ();
                update_size ();

                break;
            case Clutter.EventType.BUTTON_RELEASE:
                if (event.get_button () == Clutter.Button.PRIMARY) {
                    stop_resizing ();
                }

                break;
            case Clutter.EventType.LEAVE:
            case Clutter.EventType.ENTER:
                return Clutter.EVENT_PROPAGATE;
            default:
                break;
        }

        return Clutter.EVENT_STOP;
    }

    private void stop_resizing () {
        if (!resizing) {
            return;
        }

        if (grab != null) {
            grab.dismiss ();
            resize_button.event.disconnect (on_resize_event);
            grab = null;
        }

        resizing = false;

        update_screen_position ();

        wm.get_display ().set_cursor (Meta.Cursor.DEFAULT);
    }

    private void on_allocation_changed () {
        update_clone_clip ();
        update_size ();
    }

    private void on_close_click_clicked () {
        var duration = Utils.get_animation_duration (FADE_OUT_TIMEOUT);

        save_easing_state ();
        set_easing_duration (duration);
        opacity = 0;
        restore_easing_state ();

#if HAS_MUTTER48
        GLib.Timeout.add (duration, () => {
#else
        Clutter.Threads.Timeout.add (duration, () => {
#endif
            closed ();
            return Source.REMOVE;
        });
    }

    private void update_window_focus () {
        unowned var display = wm.get_display ();

        unowned Meta.Window focus_window = display.get_focus_window ();
        if ((focus_window != null && !Utils.get_window_is_normal (focus_window))
            || (previous_focus != null && !Utils.get_window_is_normal (previous_focus))) {
            previous_focus = focus_window;
            return;
        }

        unowned var workspace_manager = display.get_workspace_manager ();
        unowned var active_workspace = workspace_manager.get_active_workspace ();
        unowned var window = window_actor.get_meta_window ();

        if (window.appears_focused && window.located_on_workspace (active_workspace)) {
            gesture_controller.goto (1.0);
        } else if (!window_actor.is_destroyed ()) {
            gesture_controller.goto (0.0);
        }

        previous_focus = focus_window;
    }

    private void update_size () {
        int clone_container_width, clone_container_height;

        if (clone_container.has_clip) {
            float src_width = 0.0f, src_height = 0.0f;
            clone_container.get_clip (null, null, out src_width, out src_height);
            clone_container_width = (int) (src_width * clone_container.scale_x);
            clone_container_height = (int) (src_height * clone_container.scale_y);
        } else {
            clone_container_width = (int) (clone_container.width * clone_container.scale_x);
            clone_container_height = (int) (clone_container.height * clone_container.scale_y);
        }

        rounded_container.width = clone_container_width;
        rounded_container.height = clone_container_height;

        container.width = clone_container_width;
        container.height = clone_container_height;

        width = clone_container_width + button_size;
        height = clone_container_height + button_size;
    }

    /*
     * Offsets clone by csd shadow size.
     */
    private void update_clone_clip () {
        var rect = window_actor.get_meta_window ().get_frame_rect ();

        float x_offset = rect.x - window_actor.x;
        float y_offset = rect.y - window_actor.y;
        clone.set_clip (x_offset, y_offset, rect.width, rect.height);
        clone.set_position (-x_offset, -y_offset);

        clone_container.set_size (rect.width, rect.height);
    }

    private void update_clone_container_scale () {
        float src_width = 1.0f, src_height = 1.0f;
        if (clone_container.has_clip) {
            clone_container.get_clip (null, null, out src_width, out src_height);
        } else {
            src_width = clone_container.width;
            src_height = clone_container.height;
        }

        float max_width = width - button_size;
        float max_height = height - button_size;

        float new_width, new_height;
        calculate_aspect_ratio_size_fit (
            src_width, src_height,
            max_width, max_height,
            out new_width, out new_height
        );

        float window_width = 1.0f, window_height = 1.0f;
        get_target_window_size (out window_width, out window_height);

        float new_scale_x = new_width / window_width;
        float new_scale_y = new_height / window_height;

        clone_container.scale_x = new_scale_x.clamp (MINIMUM_SCALE, MAXIMUM_SCALE);
        clone_container.scale_y = new_scale_y.clamp (MINIMUM_SCALE, MAXIMUM_SCALE);

        update_clone_container_position ();
    }

    private void update_clone_container_position () {
        if (clone_container.has_clip) {
            float clip_x = 0.0f, clip_y = 0.0f;
            clone_container.get_clip (out clip_x, out clip_y, null, null);
            clone_container.x = (float) (-clip_x * clone_container.scale_x);
            clone_container.y = (float) (-clip_y * clone_container.scale_y);
        }
    }

    private void update_screen_position () {
        if (!place_window_off_screen ()) {
            place_window_in_screen ();
        }
    }

    private void place_window_in_screen () {
        off_screen = false;

        var workarea_rect = wm.get_display ().get_workspace_manager ().get_active_workspace ().get_work_area_all_monitors ();

        var screen_limit_start_x = workarea_rect.x + SCREEN_MARGIN;
        var screen_limit_end_x = workarea_rect.x + workarea_rect.width - SCREEN_MARGIN - width;
        var screen_limit_start_y = workarea_rect.y + SCREEN_MARGIN;
        var screen_limit_end_y = workarea_rect.y + workarea_rect.height - SCREEN_MARGIN - height;

        var duration = Utils.get_animation_duration (300);

        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_OUT_BACK);
        set_easing_duration (duration);
        x = x.clamp (screen_limit_start_x, screen_limit_end_x);
        y = y.clamp (screen_limit_start_y, screen_limit_end_y);
        restore_easing_state ();
    }

    private bool place_window_off_screen () {
        off_screen = false;

        var duration = Utils.get_animation_duration (300);

        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_OUT_BACK);
        set_easing_duration (duration);

        unowned var display = wm.get_display ();
        var monitor_rect = display.get_monitor_geometry (display.get_current_monitor ());

        int monitor_x = monitor_rect.x;
        int monitor_y = monitor_rect.y;
        int monitor_width = monitor_rect.width;
        int monitor_height = monitor_rect.height;

        // X axis off screen
        var off_screen_x_threshold = width * OFF_SCREEN_PERCENT;

        var off_screen_x = (x - monitor_x) < -off_screen_x_threshold;
        if (off_screen_x
                && !coord_is_in_other_monitor (x, Clutter.Orientation.HORIZONTAL)) {
            off_screen = true;
            x = monitor_x - width + OFF_SCREEN_VISIBLE_PIXELS;
        }

        var off_screen_w = (x + width) > (monitor_x + monitor_width + off_screen_x_threshold);
        if (off_screen_w
                && !coord_is_in_other_monitor (x + width, Clutter.Orientation.HORIZONTAL)) {
            off_screen = true;
            x = monitor_x + monitor_width - OFF_SCREEN_VISIBLE_PIXELS;
        }

        // Y axis off screen
        var off_screen_y_threshold = height * OFF_SCREEN_PERCENT;

        var off_screen_y = (y - monitor_y) < -off_screen_y_threshold;
        if (off_screen_y
                && !coord_is_in_other_monitor (y, Clutter.Orientation.VERTICAL)) {
            off_screen = true;
            y = monitor_y - height + OFF_SCREEN_VISIBLE_PIXELS;
        }

        var off_screen_h = (y + height) > (monitor_y + monitor_height + off_screen_y_threshold);
        if (off_screen_h
                && !coord_is_in_other_monitor (y + height, Clutter.Orientation.VERTICAL)) {
            off_screen = true;
            y = monitor_y + monitor_height - OFF_SCREEN_VISIBLE_PIXELS;
        }

        restore_easing_state ();

        return off_screen;
    }

    private bool coord_is_in_other_monitor (float coord, Clutter.Orientation axis) {
        unowned var display = wm.get_display ();
        int n_monitors = display.get_n_monitors ();

        if (n_monitors == 1) {
            return false;
        }

        int current = display.get_current_monitor ();
        for (int i = 0; i < n_monitors; i++) {
            if (i != current) {
                var monitor_rect = display.get_monitor_geometry (i);
                bool in_monitor = false;

                if (axis == Clutter.Orientation.HORIZONTAL) {
                    in_monitor = (coord >= monitor_rect.x) && (coord <= monitor_rect.x + monitor_rect.width);
                } else {
                    in_monitor = (coord >= monitor_rect.y) && (coord <= monitor_rect.y + monitor_rect.height);
                }

                if (in_monitor) {
                    return true;
                }
            }
        }

        return false;
    }

    private void get_target_window_size (out float width, out float height) {
        if (clone_container.has_clip) {
            clone_container.get_clip (null, null, out width, out height);
        } else if (clone.has_clip) {
            clone.get_clip (null, null, out width, out height);
        } else {
            width = clone.width;
            height = clone.height;
        }
    }

    private void activate () {
        warning ("Activate");

        if (off_screen) {
            place_window_in_screen ();
        } else {
            var window = window_actor.get_meta_window ();
            window.activate (Clutter.get_current_event_time ());
        }
    }
}
