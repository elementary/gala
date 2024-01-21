/*
 * Copyright 2021 Aral Balkan <mail@ar.al>
 * Copyright 2020 Mark Story <mark@mark-story.com>
 * Copyright 2017 Popye <sailor3101@gmail.com>
 * Copyright 2014 Tom Beckmann
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowSwitcher : Clutter.Actor {
    public const int ICON_SIZE = 64;
    public const int WRAPPER_PADDING = 12;

    private const string CAPTION_FONT_NAME = "Inter";
    private const int MIN_OFFSET = 64;
    private const int ANIMATION_DURATION = 200;
    // https://github.com/elementary/gala/issues/1317#issuecomment-982484415
    private const int GESTURE_RANGE_LIMIT = 10;

    public Gala.WindowManager? wm { get; construct; }
    public GestureTracker gesture_tracker { get; construct; }
    public bool opened { get; private set; default = false; }

    private bool handling_gesture = false;
    private int modifier_mask;
    private Gala.ModalProxy modal_proxy = null;
    private Granite.Settings granite_settings;
    private Clutter.Canvas canvas;
    private Clutter.Actor container;
    private Clutter.Text caption;

    private Gtk.WidgetPath widget_path;
    private Gtk.StyleContext style_context;
    private unowned Gtk.CssProvider? dark_style_provider = null;

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
            }

            update_caption_text ();
        }
    }

    private float scaling_factor = 1.0f;

    public WindowSwitcher (Gala.WindowManager wm, GestureTracker gesture_tracker) {
        Object (
            wm: wm,
            gesture_tracker: gesture_tracker
        );
    }

    construct {
        unowned var gtk_settings = Gtk.Settings.get_default ();
        granite_settings = Granite.Settings.get_default ();

        unowned var display = wm.get_display ();
        scaling_factor = display.get_monitor_scale (display.get_current_monitor ());

        canvas = new Clutter.Canvas ();
        canvas.scale_factor = scaling_factor;
        set_content (canvas);

        opacity = 0;

        // Carry out the initial draw
        create_components ();

        var effect = new ShadowEffect (40) {
            shadow_opacity = 200,
            css_class = "window-switcher",
            scale_factor = scaling_factor
        };
        add_effect (effect);

        // Redraw the components if the colour scheme changes.
        granite_settings.notify["prefers-color-scheme"].connect (() => {
            canvas.invalidate ();
            create_components ();
        });

        gtk_settings.notify["gtk-theme-name"].connect (() => {
            canvas.invalidate ();
            create_components ();
        });

        unowned var monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (() => {
            var cur_scale = display.get_monitor_scale (display.get_current_monitor ());
            if (cur_scale != scaling_factor) {
                scaling_factor = cur_scale;
                canvas.scale_factor = scaling_factor;
                effect.scale_factor = scaling_factor;
                create_components ();
            }
        });

        canvas.draw.connect (draw);
    }

    private bool draw (Cairo.Context ctx, int width, int height) {
        if (style_context == null) { // gtk is not initialized yet
            create_gtk_objects ();
        }

        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.clip ();
        ctx.reset_clip ();

        if (granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
            unowned var gtksettings = Gtk.Settings.get_default ();
            dark_style_provider = Gtk.CssProvider.get_named (gtksettings.gtk_theme_name, "dark");
            style_context.add_provider (dark_style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } else if (dark_style_provider != null) {
            style_context.remove_provider (dark_style_provider);
            dark_style_provider = null;
        }

        ctx.set_operator (Cairo.Operator.OVER);
        style_context.render_background (ctx, 0, 0, width, height);
        style_context.render_frame (ctx, 0, 0, width, height);
        ctx.restore ();

        return true;
    }

    private void create_components () {
        // We've already been constructed once, start again
        if (container != null) {
            destroy_all_children ();
        }

        var margin = InternalUtils.scale_to_int (WRAPPER_PADDING, scaling_factor);
        var layout = new Clutter.FlowLayout (Clutter.FlowOrientation.HORIZONTAL);
        container = new Clutter.Actor () {
            reactive = true,
            layout_manager = layout,
            margin_left = margin,
            margin_top = margin,
            margin_right = margin,
            margin_bottom = margin
        };

        container.button_release_event.connect (container_mouse_release);

        var caption_color = "#2e2e31";

        if (granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
            caption_color = "#fafafa";
        }

        caption = new Clutter.Text.full (CAPTION_FONT_NAME, "", Clutter.Color.from_string (caption_color));
        caption.set_pivot_point (0.5f, 0.5f);
        caption.set_ellipsize (Pango.EllipsizeMode.END);
        caption.set_line_alignment (Pango.Alignment.CENTER);

        add_child (container);
        add_child (caption);
    }

    private void create_gtk_objects () {
        widget_path = new Gtk.WidgetPath ();
        widget_path.append_type (typeof (Gtk.Window));
        widget_path.iter_set_object_name (-1, "window");

        style_context = new Gtk.StyleContext ();
        style_context.set_scale ((int)Math.round (scaling_factor));
        style_context.set_path (widget_path);
        style_context.add_class ("background");
        style_context.add_class ("csd");
        style_context.add_class ("unified");
    }

    [CCode (instance_pos = -1)]
    public void handle_switch_windows (
        Meta.Display display, Meta.Window? window,
        Clutter.KeyEvent event, Meta.KeyBinding binding
    ) {
        if (handling_gesture) {
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

    public void handle_gesture (GestureDirection direction) {
        handling_gesture = true;

        unowned var display = wm.get_display ();
        unowned var workspace_manager = display.get_workspace_manager ();
        unowned var active_workspace = workspace_manager.get_active_workspace ();

        var windows_exist = collect_all_windows (display, active_workspace);
        if (!windows_exist) {
            return;
        }
        open_switcher ();

        // if direction == LEFT we need to move to the end of the list first, thats why last_window_index is set to -1
        var last_window_index = direction == RIGHT ? 0 : -1;
        GestureTracker.OnUpdate on_animation_update = (percentage) => {
            var window_index = GestureTracker.animation_value (0, GESTURE_RANGE_LIMIT, percentage, true);

            if (window_index >= container.get_n_children ()) {
                return;
            }

            if (window_index > last_window_index) {
                while (last_window_index < window_index) {
                    next_window (direction == LEFT);
                    last_window_index++;
                }
            } else if (window_index < last_window_index) {
                while (last_window_index > window_index) {
                    next_window (direction == RIGHT);
                    last_window_index--;
                }
            }
        };

        GestureTracker.OnEnd on_animation_end = (percentage, cancel_action, calculated_duration) => {
            handling_gesture = false;
            close_switcher (wm.get_display ().get_current_time ());
        };

        gesture_tracker.connect_handlers (null, (owned) on_animation_update, (owned) on_animation_end);
    }

    private bool collect_all_windows (Meta.Display display, Meta.Workspace? workspace) {
        var windows = display.get_tab_list (Meta.TabList.NORMAL, workspace);
        if (windows == null) {
            return false;
        }

        unowned var current_window = display.get_tab_current (Meta.TabList.NORMAL, workspace);
        if (current_window == null) {
            current_icon = null;
        }

        container.width = -1;
        container.destroy_all_children ();

        foreach (unowned var window in windows) {
            var icon = new WindowSwitcherIcon (window, ICON_SIZE, scaling_factor);
            if (window == current_window) {
                current_icon = icon;
            }

            add_icon (icon);
        }

        return true;
    }

    private bool collect_current_windows (Meta.Display display, Meta.Workspace? workspace) {
        var windows = display.get_tab_list (Meta.TabList.NORMAL, workspace);
        if (windows == null) {
            return false;
        }

        unowned var current_window = display.get_tab_current (Meta.TabList.NORMAL, workspace);
        if (current_window == null) {
            current_icon = null;
            return false;
        }

        container.width = -1;
        container.destroy_all_children ();

        unowned var window_tracker = ((WindowManagerGala) wm).window_tracker;
        var app = window_tracker.get_app_for_window (current_window);
        foreach (unowned var window in windows) {
            if (window_tracker.get_app_for_window (window) == app) {
                var icon = new WindowSwitcherIcon (window, ICON_SIZE, scaling_factor);
                if (window == current_window) {
                    current_icon = icon;
                }

                add_icon (icon);
            }
        }

        return true;
    }

    private void add_icon (WindowSwitcherIcon icon) {
        container.add_child (icon);

        icon.enter_event.connect (() => {
            current_icon = icon;
            return Clutter.EVENT_PROPAGATE;
        });
    }

    private void open_switcher () {
        if (container.get_n_children () == 0) {
            Clutter.get_default_backend ().get_default_seat ().bell_notify ();
            return;
        }

        if (opened) {
            return;
        }

        opacity = 0;

        unowned var display = wm.get_display ();
        var monitor = display.get_current_monitor ();
        var geom = display.get_monitor_geometry (monitor);

        float container_width;
        container.get_preferred_width (
            InternalUtils.scale_to_int (ICON_SIZE, scaling_factor) + container.margin_left + container.margin_right,
            null,
            out container_width
        );
        if (container_width + InternalUtils.scale_to_int (MIN_OFFSET, scaling_factor) * 2 > geom.width) {
            container.width = geom.width - InternalUtils.scale_to_int (MIN_OFFSET, scaling_factor) * 2;
        }

        float nat_width, nat_height;
        container.get_preferred_size (null, null, out nat_width, out nat_height);

        var switcher_height = (int) (nat_height + caption.height / 2 - container.margin_bottom + WRAPPER_PADDING * 3 * scaling_factor);
        set_size ((int) nat_width, switcher_height);
        canvas.set_size ((int) nat_width, switcher_height);
        canvas.invalidate ();

        // container width might have changed, so we must update caption width too
        update_caption_text ();

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
        }

        save_easing_state ();
        set_easing_duration (wm.enable_animations ? ANIMATION_DURATION : 0);
        opacity = show ? 255 : 0;
        restore_easing_state ();

        container.reactive = show;
    }

    private void push_modal () {
        modal_proxy = wm.push_modal (this);
        modal_proxy.set_keybinding_filter ((binding) => {
            var action = Meta.Prefs.get_keybinding_action (binding.get_name ());

            switch (action) {
                case Meta.KeyBindingAction.NONE:
                case Meta.KeyBindingAction.LOCATE_POINTER_KEY:
                case Meta.KeyBindingAction.SWITCH_APPLICATIONS:
                case Meta.KeyBindingAction.SWITCH_APPLICATIONS_BACKWARD:
                case Meta.KeyBindingAction.SWITCH_WINDOWS:
                case Meta.KeyBindingAction.SWITCH_WINDOWS_BACKWARD:
                case Meta.KeyBindingAction.SWITCH_GROUP:
                case Meta.KeyBindingAction.SWITCH_GROUP_BACKWARD:
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
        Clutter.Actor actor;

        if (container.get_n_children () == 1 && current_icon != null) {
            Clutter.get_default_backend ().get_default_seat ().bell_notify ();
            return;
        }

        if (current_icon == null) {
            actor = container.get_first_child ();
        } else if (!backward) {
            actor = current_icon.get_next_sibling ();
            if (actor == null) {
                actor = container.get_first_child ();
            }
        } else {
            actor = current_icon.get_previous_sibling ();
            if (actor == null) {
                actor = container.get_last_child ();
            }
        }

        current_icon = (WindowSwitcherIcon) actor;
    }

    private void update_caption_text () {
        var current_window = current_icon != null ? current_icon.window : null;
        var current_caption = current_window != null ? current_window.title : "n/a";
        caption.set_text (current_caption);

        // Make caption smaller than the wrapper, so it doesn't overflow.
        caption.width = width - WRAPPER_PADDING * 2 * scaling_factor;
        caption.set_position (
            InternalUtils.scale_to_int (WRAPPER_PADDING, scaling_factor),
            (int) (height - caption.height / 2 - InternalUtils.scale_to_int (WRAPPER_PADDING, scaling_factor) * 2)
        );
    }

    public override void key_focus_out () {
        if (!handling_gesture) {
            close_switcher (wm.get_display ().get_current_time ());
        }
    }

#if HAS_MUTTER45
    private bool container_mouse_release (Clutter.Event event) {
#else
    private bool container_mouse_release (Clutter.ButtonEvent event) {
#endif
        if (opened && event.get_button () == Clutter.Button.PRIMARY && !handling_gesture) {
            close_switcher (event.get_time ());
        }

        return true;
    }

#if HAS_MUTTER45
    public override bool key_release_event (Clutter.Event event) {
#else
    public override bool key_release_event (Clutter.KeyEvent event) {
#endif
        if ((get_current_modifiers () & modifier_mask) == 0 && !handling_gesture) {
            close_switcher (event.get_time ());
        }

        return Clutter.EVENT_PROPAGATE;
    }

#if HAS_MUTTER45
    public override bool key_press_event (Clutter.Event event) {
#else
    public override bool key_press_event (Clutter.KeyEvent event) {
#endif
        switch (event.get_key_symbol ()) {
            case Clutter.Key.Right:
                if (!handling_gesture) {
                    next_window (false);
                }
                return Clutter.EVENT_STOP;
            case Clutter.Key.Left:
                if (!handling_gesture) {
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
        wm.get_display ().get_cursor_tracker ().get_pointer (null, out modifiers);

        return modifiers & Clutter.ModifierType.MODIFIER_MASK;
    }
}
