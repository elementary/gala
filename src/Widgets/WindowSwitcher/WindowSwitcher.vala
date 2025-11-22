/*
 * Copyright 2021 Aral Balkan <mail@ar.al>
 * Copyright 2020 Mark Story <mark@mark-story.com>
 * Copyright 2017 Popye <sailor3101@gmail.com>
 * Copyright 2014 Tom Beckmann
 * Copyright 2023-2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowSwitcher : CanvasActor, GestureTarget, RootTarget {
    public const int WRAPPER_PADDING = 12;

    private const int MIN_OFFSET = 64;
    private const double GESTURE_STEP = 0.2;

    public Clutter.Actor? actor { get { return this; } }
    public WindowManager wm { get; construct; }
    public bool opened { get; private set; default = false; }
    public float monitor_scale { get; private set; default = 1.0f; }

    private GestureController gesture_controller;
    private int modifier_mask;
    private Gala.ModalProxy modal_proxy = null;
    private Drawing.StyleManager style_manager;
    private Clutter.Actor container;
    private Gala.Text caption;
    private ShadowEffect shadow_effect;
    private BackgroundBlurEffect blur_effect;

    private WindowSwitcherIcon? _current_icon = null;
    private WindowSwitcherIcon? current_icon {
        get {
            return _current_icon;
        }
        set {
            if (_current_icon != null) {
                _current_icon.selected = false;
            }

            _current_icon = value;
            if (_current_icon != null) {
                _current_icon.selected = true;
                _current_icon.grab_key_focus ();
            }

            var current_window = _current_icon != null ? _current_icon.window : null;
            caption.text = current_window != null ? current_window.title : "n/a";
        }
    }

    private double previous_progress = 0d;

    public WindowSwitcher (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        style_manager = Drawing.StyleManager.get_instance ();

        gesture_controller = new GestureController (SWITCH_WINDOWS, wm) {
            overshoot_upper_clamp = int.MAX,
            overshoot_lower_clamp = int.MIN,
            snap = false
        };
        gesture_controller.enable_touchpad (wm.stage);
        gesture_controller.notify["recognizing"].connect (recognizing_changed);
        add_gesture_controller (gesture_controller);

        container = new Clutter.Actor () {
            reactive = true,
#if HAS_MUTTER46
            layout_manager = new Clutter.FlowLayout (Clutter.Orientation.HORIZONTAL)
#else
            layout_manager = new Clutter.FlowLayout (Clutter.FlowOrientation.HORIZONTAL)
#endif
        };

        get_accessible ().accessible_name = _("Window switcher");
        container.get_accessible ().accessible_role = LIST;

        caption = new Gala.Text () {
            ellipsize = END,
            line_alignment = CENTER
        };

        add_child (container);
        add_child (caption);

        reactive = true;
        visible = false;
        opacity = 0;
        layout_manager = new Clutter.BoxLayout () {
            orientation = VERTICAL
        };

        notify["monitor-scale"].connect (scale);
        scale ();

        shadow_effect = new ShadowEffect ("window-switcher", monitor_scale) {
            border_radius = 10,
            shadow_opacity = 100
        };
        bind_property ("monitor-scale", shadow_effect, "monitor-scale");
        add_effect (shadow_effect);


        blur_effect = new BackgroundBlurEffect (40, 9, monitor_scale);
        bind_property ("monitor-scale", blur_effect, "monitor-scale");
        add_effect (blur_effect);

        container.button_release_event.connect (container_mouse_release);

        // Redraw the components if the colour scheme changes.
        style_manager.notify["prefers-color-scheme"].connect (content.invalidate);

        notify["opacity"].connect (() => visible = opacity != 0);
    }

    private void scale () {
        var margin = Utils.scale_to_int (WRAPPER_PADDING, monitor_scale);

        container.margin_left = margin;
        container.margin_right = margin;
        container.margin_bottom = margin;
        container.margin_top = margin;

        caption.margin_left = margin;
        caption.margin_right = margin;
        caption.margin_bottom = margin;
    }

    protected override void get_preferred_width (float for_height, out float min_width, out float natural_width) {
        min_width = 0;

        float preferred_nat_width;
        base.get_preferred_width (for_height, null, out preferred_nat_width);

        unowned var display = wm.get_display ();
        var geom = display.get_monitor_geometry (display.get_current_monitor ());

        float container_nat_width;
        container.get_preferred_size (null, null, out container_nat_width, null);

        var max_width = float.min (
            geom.width - Utils.scale_to_int (MIN_OFFSET * 2, monitor_scale), // Don't overflow the monitor
            container_nat_width // Ellipsize the label if it's longer than the icons
        );

        natural_width = float.min (max_width, preferred_nat_width);
    }

    protected override void draw (Cairo.Context ctx, int width, int height) {
        var background_color = Drawing.Color.LIGHT_BACKGROUND;
        var border_color = Drawing.Color.LIGHT_BORDER;
        var caption_color = "#2e2e31";
        var highlight_color = Drawing.Color.LIGHT_HIGHLIGHT;

        if (style_manager.prefers_color_scheme == Drawing.StyleManager.ColorScheme.DARK) {
            background_color = Drawing.Color.DARK_BACKGROUND;
            border_color = Drawing.Color.DARK_BORDER;
            caption_color = "#fafafa";
            highlight_color = Drawing.Color.DARK_HIGHLIGHT;
        }

#if HAS_MUTTER47
        caption.color = Cogl.Color.from_string (caption_color);
#else
        caption.color = Clutter.Color.from_string (caption_color);
#endif

        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();

        ctx.set_operator (Cairo.Operator.SOURCE);

        var stroke_width = Utils.scale_to_int (1, monitor_scale);
        Drawing.Utilities.cairo_rounded_rectangle (
            ctx,
            stroke_width / 2.0, stroke_width / 2.0,
            width - stroke_width, height - stroke_width,
            Utils.scale_to_int (9, monitor_scale)
        );

        ctx.set_source_rgba (
            background_color.red / 255.0,
            background_color.green / 255.0,
            background_color.blue / 255.0,
            0.6
        );
        ctx.fill_preserve ();

        ctx.set_line_width (stroke_width);
        ctx.set_source_rgba (
            border_color.red / 255.0,
            border_color.green / 255.0,
            border_color.blue / 255.0,
            border_color.alpha / 255.0
        );
        ctx.stroke ();
        ctx.restore ();

        Drawing.Utilities.cairo_rounded_rectangle (
            ctx, stroke_width * 1.5, stroke_width * 1.5,
            width - stroke_width * 3,
            height - stroke_width * 3,
            Utils.scale_to_int (8, monitor_scale)
        );

        ctx.set_line_width (stroke_width);
        ctx.set_source_rgba (
            highlight_color.red / 255.0,
            highlight_color.green / 255.0,
            highlight_color.blue / 255.0,
            0.3
        );
        ctx.stroke ();
        ctx.restore ();
    }

    public void propagate (UpdateType update_type, GestureAction action, double progress) {
        if (update_type != UPDATE || container.get_n_children () == 0) {
            return;
        }

        var is_step = ((int) (previous_progress / GESTURE_STEP) - (int) (progress / GESTURE_STEP)).abs () >= 1;

        previous_progress = progress;

        if (container.get_n_children () == 1 && current_icon != null && is_step) {
            InternalUtils.bell_notify (wm.get_display ());
            return;
        }

        var current_index = (int) (progress / GESTURE_STEP) % container.get_n_children ();

        if (current_index < 0) {
            current_index = container.get_n_children () + current_index;
        }

        var new_icon = (WindowSwitcherIcon) container.get_child_at_index (current_index);
        if (new_icon != current_icon) {
            current_icon = new_icon;
        }
    }

    private void select_icon (WindowSwitcherIcon? icon) {
        if (icon == null) {
            gesture_controller.progress = 0;
            current_icon = null;
            return;
        }

        int index = 0;
        for (var child = container.get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (child == icon) {
                gesture_controller.progress = index * GESTURE_STEP;
                break;
            }
            index++;
        }
    }

    public void handle_switch_windows (
        Meta.Display display, Meta.Window? window,
        Clutter.KeyEvent? event, Meta.KeyBinding binding
    ) {
        if (gesture_controller.recognizing) {
            return;
        }

        var workspace = display.get_workspace_manager ().get_active_workspace ();

        // copied from gnome-shell, finds the primary modifier in the mask
        var mask = binding.get_mask ();
        if (mask == 0) {
            modifier_mask = 0;
        } else {
            modifier_mask = 1;
            while (mask > 1) {
                mask >>= 1;
                modifier_mask <<= 1;
            }
        }

        if (!opened) {
            bool windows_exist;
            if (binding.get_name ().has_prefix ("switch-group")) {
                windows_exist = collect_current_windows (display, workspace);
            } else {
                windows_exist = collect_all_windows (display, workspace);
            }

            if (!windows_exist) {
                return;
            }

            open_switcher ();
        }

        var binding_name = binding.get_name ();
        var backward = binding_name.has_suffix ("-backward");

        next_window (backward);
    }

    private void recognizing_changed () {
        if (gesture_controller.recognizing) {
            unowned var display = wm.get_display ();
            unowned var workspace_manager = display.get_workspace_manager ();
            unowned var active_workspace = workspace_manager.get_active_workspace ();

            var windows_exist = collect_all_windows (display, active_workspace);
            if (!windows_exist) {
                return;
            }
            open_switcher ();
        } else {
            close_switcher (wm.get_display ().get_current_time ());
        }
    }

    private bool collect_all_windows (Meta.Display display, Meta.Workspace? workspace) {
        container.remove_all_children ();
        select_icon (null);

        monitor_scale = Utils.get_ui_scaling_factor (display, display.get_current_monitor ());

        var windows = display.get_tab_list (Meta.TabList.NORMAL, workspace);
        if (windows == null) {
            return false;
        }

        unowned var current_window = display.get_tab_current (Meta.TabList.NORMAL, workspace);
        foreach (unowned var window in windows) {
            var icon = new WindowSwitcherIcon (window, monitor_scale);
            bind_property ("monitor-scale", icon, "monitor-scale");
            add_icon (icon);

            if (window == current_window) {
                select_icon (icon);
            }
        }

        return true;
    }

    private bool collect_current_windows (Meta.Display display, Meta.Workspace? workspace) {
        container.remove_all_children ();
        select_icon (null);

        monitor_scale = Utils.get_ui_scaling_factor (display, display.get_current_monitor ());

        var windows = display.get_tab_list (Meta.TabList.NORMAL, workspace);
        if (windows == null) {
            return false;
        }

        unowned var current_window = display.get_tab_current (Meta.TabList.NORMAL, workspace);
        if (current_window == null) {
            return false;
        }

        unowned var window_tracker = ((WindowManagerGala) wm).window_tracker;
        var app = window_tracker.get_app_for_window (current_window);
        foreach (unowned var window in windows) {
            if (window_tracker.get_app_for_window (window) == app) {
                var icon = new WindowSwitcherIcon (window, monitor_scale);
                bind_property ("monitor-scale", icon, "monitor-scale");
                add_icon (icon);

                if (window == current_window) {
                    select_icon (icon);
                }
            }
        }

        return true;
    }

    private void add_icon (WindowSwitcherIcon icon) {
        container.add_child (icon);
        icon.get_accessible ().accessible_parent = container.get_accessible ();

        icon.motion_event.connect ((_icon, event) => {
            if (current_icon != _icon && !gesture_controller.recognizing) {
                select_icon ((WindowSwitcherIcon) _icon);
            }

            return Clutter.EVENT_PROPAGATE;
        });
    }

    private void open_switcher () {
        unowned var display = wm.get_display ();

        if (container.get_n_children () == 0) {
            InternalUtils.bell_notify (display);
            return;
        }

        if (opened) {
            return;
        }

        //Although we are setting visible via the opacity notify handler anyway
        //we have to set it here manually otherwise the size gotten via get_preferred_size is wrong
        visible = true;

        float width, height;
        get_preferred_size (null, null, out width, out height);

        var geom = display.get_monitor_geometry (display.get_current_monitor ());

        set_position (
            (int) (geom.x + (geom.width - width) / 2),
            (int) (geom.y + (geom.height - height) / 2)
        );

        toggle_display (true);
    }

    private void toggle_display (bool show) {
        if (opened == show) {
            return;
        }

        opened = show;
        if (show) {
            push_modal ();
        } else {
            wm.pop_modal (modal_proxy);
            get_stage ().set_key_focus (null);
        }

        save_easing_state ();
        set_easing_duration (Utils.get_animation_duration (AnimationDuration.HIDE));
        opacity = show ? 255 : 0;
        restore_easing_state ();
    }

    private void push_modal () {
        modal_proxy = wm.push_modal (get_stage (), true);
        modal_proxy.allow_actions ({ SWITCH_WINDOWS });
        modal_proxy.set_keybinding_filter ((binding) => {
            var action = Meta.Prefs.get_keybinding_action (binding.get_name ());

            switch (action) {
                case Meta.KeyBindingAction.NONE:
                case Meta.KeyBindingAction.LOCATE_POINTER_KEY:
                    return false;
                default:
                    break;
            }

            return true;
        });

    }

    private void close_switcher (uint32 time, bool cancel = false) {
        if (!opened) {
            return;
        }

        var window = current_icon.window;
        if (window == null) {
            return;
        }

        if (!cancel) {
            unowned var workspace = window.get_workspace ();
            if (workspace != wm.get_display ().get_workspace_manager ().get_active_workspace ()) {
                workspace.activate_with_focus (window, time);
            } else {
                window.activate (time);
            }
        }

        toggle_display (false);
    }

    private void next_window (bool backward) {
        gesture_controller.progress += backward ? -GESTURE_STEP : GESTURE_STEP;
    }

    public override void key_focus_out () {
        if (!gesture_controller.recognizing) {
            close_switcher (wm.get_display ().get_current_time ());
        }
    }

    private bool container_mouse_release (Clutter.Event event) {
        if (opened && event.get_button () == Clutter.Button.PRIMARY && !gesture_controller.recognizing) {
            close_switcher (event.get_time ());
        }

        return true;
    }

    public override bool key_release_event (Clutter.Event event) {
        if ((get_current_modifiers () & modifier_mask) == 0 && !gesture_controller.recognizing) {
            close_switcher (event.get_time ());
        }

        return Clutter.EVENT_PROPAGATE;
    }

    public override bool key_press_event (Clutter.Event event) {
        switch (event.get_key_symbol ()) {
            case Clutter.Key.Right:
                if (!gesture_controller.recognizing) {
                    next_window (false);
                }
                return Clutter.EVENT_STOP;
            case Clutter.Key.Left:
                if (!gesture_controller.recognizing) {
                    next_window (true);
                }
                return Clutter.EVENT_STOP;
            case Clutter.Key.Escape:
                close_switcher (event.get_time (), true);
                return Clutter.EVENT_PROPAGATE;
            case Clutter.Key.Return:
                close_switcher (event.get_time (), false);
                return Clutter.EVENT_PROPAGATE;
        }

        return Clutter.EVENT_PROPAGATE;
    }


    private inline Clutter.ModifierType get_current_modifiers () {
        Clutter.ModifierType modifiers;
#if HAS_MUTTER48
        unowned var tracker = wm.get_display ().get_compositor ().get_backend ().get_cursor_tracker ();
#else
        unowned var tracker = wm.get_display ().get_cursor_tracker ();
#endif
        tracker.get_pointer (null, out modifiers);

        return modifiers & Clutter.ModifierType.MODIFIER_MASK;
    }
}
