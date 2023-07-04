/*
 * Copyright 2017 Adam Bieńkowski
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.Plugins.PIP.PopupWindow : Clutter.Actor {
    private int button_size;
    private int container_margin;
    private const int SHADOW_SIZE = 100;
    private const uint FADE_OUT_TIMEOUT = 200;
    private const float MINIMUM_SCALE = 0.1f;
    private const float MAXIMUM_SCALE = 1.0f;
    private const int SCREEN_MARGIN = 0;
    private const float OFF_SCREEN_PERCENT = 0.5f;
    private const int OFF_SCREEN_VISIBLE_PIXELS = 80;

    public signal void closed ();

    public Gala.WindowManager wm { get; construct; }
    public Meta.WindowActor window_actor { get; construct; }

    private bool dynamic_container = false;

    private Clutter.Actor clone;
    private Clutter.Actor container;
    private Clutter.Actor close_button;
    private Clutter.Actor resize_button;
    private Clutter.ClickAction close_action;
    private DragDropAction move_action;

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

    private static bool get_window_is_normal (Meta.Window window) {
        var window_type = window.get_window_type ();
        return window_type == Meta.WindowType.NORMAL
            || window_type == Meta.WindowType.DIALOG
            || window_type == Meta.WindowType.MODAL_DIALOG;
    }

    public PopupWindow (Gala.WindowManager wm, Meta.WindowActor window_actor) {
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

        unowned var window = window_actor.get_meta_window ();
        window.unmanaged.connect (on_close_click_clicked);
        window.notify["appears-focused"].connect (update_window_focus);

        unowned var workspace_manager = wm.get_display ().get_workspace_manager ();
        workspace_manager.active_workspace_changed.connect (update_window_focus);

        clone = new Clutter.Clone (window_actor);

        move_action = new DragDropAction (DragDropActionType.SOURCE, "pip");
        move_action.drag_begin.connect (on_move_begin);
        move_action.drag_canceled.connect (on_move_end);
        move_action.actor_clicked.connect (activate);

        container = new Clutter.Actor ();
        container.reactive = true;
        container.set_scale (0.35f, 0.35f);
        container.add_effect (new ShadowEffect (SHADOW_SIZE) { css_class = "window-clone" });
        container.add_child (clone);
        container.add_action (move_action);

        update_size ();
        update_container_position ();

        Meta.Rectangle monitor_rect;
        get_current_monitor_rect (out monitor_rect);

        float x_position, y_position;
        if (Clutter.get_default_text_direction () == Clutter.TextDirection.RTL) {
            x_position = SCREEN_MARGIN + monitor_rect.x;
        } else {
            x_position = monitor_rect.width + monitor_rect.x - SCREEN_MARGIN - width;
        }
        y_position = monitor_rect.height + monitor_rect.y - SCREEN_MARGIN - height;

        set_position (x_position, y_position);

        close_action = new Clutter.ClickAction ();
        close_action.clicked.connect (on_close_click_clicked);

        close_button = Gala.Utils.create_close_button (scale);
        close_button.opacity = 0;
        close_button.reactive = true;
        // TODO: Check if close button should be on the right
        close_button.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.X_AXIS, 0.0f));
        close_button.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.Y_AXIS, 0.0f));
        close_button.add_action (close_action);

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
        update_clone_clip ();
    }

    public override void show () {
        base.show ();

        opacity = 0;

        save_easing_state ();
        set_easing_duration (wm.enable_animations ? 200 : 0);
        opacity = 255;
        restore_easing_state ();
    }

    public override void hide () {
        opacity = 255;

        var duration = wm.enable_animations ? 200 : 0;
        save_easing_state ();
        set_easing_duration (duration);
        opacity = 0;
        restore_easing_state ();

        if (duration == 0) {
            base.hide ();
        } else {
            ulong completed_id = 0;
            completed_id = transitions_completed.connect (() => {
                disconnect (completed_id);
                base.hide ();
            });
        }
    }

    public override bool enter_event (Clutter.CrossingEvent event) {
        var duration = wm.enable_animations ? 300 : 0;

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

    public override bool leave_event (Clutter.CrossingEvent event) {
        var duration = wm.enable_animations ? 300 : 0;

        close_button.save_easing_state ();
        close_button.set_easing_duration (duration);
        close_button.opacity = 0;
        close_button.restore_easing_state ();

        resize_button.save_easing_state ();
        resize_button.set_easing_duration (duration);
        resize_button.opacity = 0;
        resize_button.restore_easing_state ();

        return Clutter.EVENT_PROPAGATE;
    }

    public void set_container_clip (Graphene.Rect? container_clip) {
        container.clip_rect = container_clip;
        dynamic_container = true;
        update_container_scale ();
        on_allocation_changed ();
    }

    private Clutter.Actor on_move_begin () {
        return this;
    }

    private void on_move_end () {
        reactive = true;
        update_screen_position ();
    }

    private bool on_resize_button_press (Clutter.ButtonEvent event) {
        if (resizing || event.button != 1) {
            return Clutter.EVENT_STOP;
        }

        resizing = true;

        resize_start_x = event.x;
        resize_start_y = event.y;

        begin_resize_width = width;
        begin_resize_height = height;

        grab = resize_button.get_stage ().grab (resize_button);
        resize_button.event.connect (on_resize_event);

        return Clutter.EVENT_PROPAGATE;
    }

    private bool on_resize_event (Clutter.Event event) {
        if (!resizing) {
            return Clutter.EVENT_STOP;
        }

        switch (event.get_type ()) {
            case Clutter.EventType.MOTION:
                unowned var motion_event = (Clutter.MotionEvent) event;
                var mods = event.get_state ();
                if (!(Clutter.ModifierType.BUTTON1_MASK in mods)) {
                    stop_resizing ();
                    break;
                }

                float diff_x = motion_event.x - resize_start_x;
                float diff_y = motion_event.y - resize_start_y;

                width = begin_resize_width + diff_x;
                height = begin_resize_height + diff_y;

                update_container_scale ();
                update_size ();

                break;
            case Clutter.EventType.BUTTON_RELEASE:
                if (event.get_button () == 1) {
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
    }

    private void on_allocation_changed () {
        update_clone_clip ();
        update_size ();
    }

    private void on_close_click_clicked () {
        var duration = wm.enable_animations ? FADE_OUT_TIMEOUT : 0;

        save_easing_state ();
        set_easing_duration (duration);
        opacity = 0;
        restore_easing_state ();

        Clutter.Threads.Timeout.add (duration, () => {
            closed ();
            return Source.REMOVE;
        });
    }

    private void update_window_focus () {
        unowned Meta.Window focus_window = wm.get_display ().get_focus_window ();
        if ((focus_window != null && !get_window_is_normal (focus_window))
            || (previous_focus != null && !get_window_is_normal (previous_focus))) {
            previous_focus = focus_window;
            return;
        }

        unowned var workspace_manager = wm.get_display ().get_workspace_manager ();
        unowned var active_workspace = workspace_manager.get_active_workspace ();
        unowned var window = window_actor.get_meta_window ();

        if (window.appears_focused && window.located_on_workspace (active_workspace)) {
            hide ();
        } else if (!window_actor.is_destroyed ()) {
            show ();
        }

        previous_focus = focus_window;
    }

    private void update_size () {
        if (dynamic_container) {
            float src_width = 0.0f, src_height = 0.0f;
            container.get_clip (null, null, out src_width, out src_height);
            width = (int)(src_width * container.scale_x + button_size);
            height = (int)(src_height * container.scale_y + button_size);
        } else {
            width = (int)(container.width * container.scale_x + button_size);
            height = (int)(container.height * container.scale_y + button_size);
        }
    }

    private void update_clone_clip () {
        var rect = window_actor.get_meta_window ().get_frame_rect ();

        float x_offset = rect.x - window_actor.x;
        float y_offset = rect.y - window_actor.y;
        clone.set_clip (x_offset, y_offset, rect.width, rect.height);
        clone.set_position (-x_offset, -y_offset);

        container.set_size (rect.width, rect.height);
    }

    private void update_container_scale () {
        float src_width = 1.0f, src_height = 1.0f;
        if (dynamic_container) {
            container.get_clip (null, null, out src_width, out src_height);
        } else {
            src_width = container.width;
            src_height = container.height;
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

        container.scale_x = new_scale_x.clamp (MINIMUM_SCALE, MAXIMUM_SCALE);
        container.scale_y = new_scale_y.clamp (MINIMUM_SCALE, MAXIMUM_SCALE);

        update_container_position ();
    }

    private void update_container_position () {
        if (dynamic_container) {
            float clip_x = 0.0f, clip_y = 0.0f;
            container.get_clip (out clip_x, out clip_y, null, null);
            container.x = (float)(-clip_x * container.scale_x + container_margin);
            container.y = (float)(-clip_y * container.scale_y + container_margin);
        }
    }

    private void update_screen_position () {
        if (!place_window_off_screen ()) {
            place_window_in_screen ();
        }
    }

    private void place_window_in_screen () {
        off_screen = false;

        Meta.Rectangle monitor_rect;
        get_current_monitor_rect (out monitor_rect);

        int monitor_x = monitor_rect.x;
        int monitor_y = monitor_rect.y;
        int monitor_width = monitor_rect.width;
        int monitor_height = monitor_rect.height;

        var screen_limit_start_x = SCREEN_MARGIN + monitor_x;
        var screen_limit_end_x = monitor_width + monitor_x - SCREEN_MARGIN - width;
        var screen_limit_start_y = SCREEN_MARGIN + monitor_y;
        var screen_limit_end_y = monitor_height + monitor_y - SCREEN_MARGIN - height;

        var duration = wm.enable_animations ? 300 : 0;

        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_OUT_BACK);
        set_easing_duration (duration);
        x = x.clamp (screen_limit_start_x, screen_limit_end_x);
        y = y.clamp (screen_limit_start_y, screen_limit_end_y);
        restore_easing_state ();
    }

    private bool place_window_off_screen () {
        off_screen = false;

        var duration = wm.enable_animations ? 300 : 0;

        save_easing_state ();
        set_easing_mode (Clutter.AnimationMode.EASE_OUT_BACK);
        set_easing_duration (duration);

        Meta.Rectangle monitor_rect;
        get_current_monitor_rect (out monitor_rect);

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
        var display = wm.get_display ();
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

    private void get_current_monitor_rect (out Meta.Rectangle rect) {
        var display = wm.get_display ();
        rect = display.get_monitor_geometry (display.get_current_monitor ());
    }

    private void get_target_window_size (out float width, out float height) {
        if (dynamic_container) {
            container.get_clip (null, null, out width, out height);
        } else if (clone.has_clip) {
            clone.get_clip (null, null, out width, out height);
        } else {
            width = clone.width;
            height = clone.height;
        }
    }

    private void activate () {
        if (off_screen) {
            place_window_in_screen ();
        } else {
            var window = window_actor.get_meta_window ();
            window.activate (Clutter.get_current_event_time ());
        }
    }
}
