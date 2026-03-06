/*
 * Copyright 2021 Aral Balkan <mail@ar.al>
 * Copyright 2020 Mark Story <mark@mark-story.com>
 * Copyright 2017 Popye <sailor3101@gmail.com>
 * Copyright 2014 Tom Beckmann
 * Copyright 2023-2026 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowSwitcher : AbstractSwitcher, GestureTarget, RootTarget {
    private const double GESTURE_STEP = 0.2;

    public bool opened { get; private set; default = false; }

    private GestureController gesture_controller;
    private int modifier_mask;
    private Gala.ModalProxy? modal_proxy;
    private int previous_icon_index = 0;

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
            caption_text = current_window != null ? current_window.title : "n/a";
        }
    }

    public WindowSwitcher (WindowManager wm) {
        base (wm);
    }

    construct {
        gesture_controller = new GestureController (SWITCH_WINDOWS) {
            overshoot_upper_clamp = int.MAX,
            overshoot_lower_clamp = int.MIN,
            snap = false
        };
        gesture_controller.add_trigger (new GlobalTrigger (SWITCH_WINDOWS, wm));
        gesture_controller.notify["recognizing"].connect (recognizing_changed);
        add_gesture_controller (gesture_controller);

        get_accessible ().accessible_name = _("Window switcher");

        container.button_release_event.connect (container_mouse_release);
    }

    public override void propagate (GestureTarget.UpdateType update_type, GestureAction action, double progress) {
        if (update_type != UPDATE || container.get_n_children () == 0) {
            return;
        }

        var new_index = (int) Math.round (progress / GESTURE_STEP);
        var is_step = new_index != previous_icon_index;

        previous_icon_index = new_index;

        if (container.get_n_children () == 1 && current_icon != null && is_step) {
            InternalUtils.bell_notify (wm.get_display ());
            return;
        }

        var current_index = new_index % container.get_n_children ();

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
        if (show && modal_proxy == null) {
            modal_proxy = wm.push_modal (get_stage (), true);
            modal_proxy.allow_actions (SWITCH_WINDOWS | LOCATE_POINTER | MEDIA_KEYS);
        } else if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
            modal_proxy = null;

            get_stage ().set_key_focus (null);
        }

        save_easing_state ();
        set_easing_duration (Utils.get_animation_duration (AnimationDuration.HIDE));
        opacity = show ? 255 : 0;
        restore_easing_state ();
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
