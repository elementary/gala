/*
 * Copyright 2012 Tom Beckmann
 * Copyright 2012 Rico Tzschichholz
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowOverview : ActorTarget, RootTarget, ActivatableComponent {
    private const int BORDER = 10;
    private const int TOP_GAP = 30;
    private const int BOTTOM_GAP = 100;

    public Clutter.Actor? actor { get { return this; } }
    public WindowManager wm { get; construct; }

    private GestureController gesture_controller; // Currently not used for actual touchpad gestures but only as controller
    private ModalProxy? modal_proxy = null;
    private WindowCloneContainer window_clone_container;

    private uint64[]? window_ids = null;
    private Meta.Window? last_selected_window = null;
    private bool opened = false;

    public WindowOverview (WindowManager wm) {
        Object (wm : wm);
    }

    construct {
        visible = false;
        reactive = true;

        gesture_controller = new GestureController (MULTITASKING_VIEW, wm);
        add_gesture_controller (gesture_controller);
    }

    public override void end_progress (Gala.GestureAction action) {
        if (action == MULTITASKING_VIEW && get_current_progress (MULTITASKING_VIEW) == 0.0) {
            if (last_selected_window != null) {
                last_selected_window.get_workspace ().activate_with_focus (last_selected_window, Meta.CURRENT_TIME);
            }

            cleanup ();
        }
    }

    public override bool key_press_event (Clutter.Event event) {
        if (!is_opened ()) {
            return Clutter.EVENT_PROPAGATE;
        }

        return window_clone_container.key_press_event (event);
    }

    public override bool button_release_event (Clutter.Event event) {
        if (event.get_button () == Clutter.Button.PRIMARY) {
            close ();
        }

        return Clutter.EVENT_STOP;
    }

    /**
     * {@inheritDoc}
     */
    public bool is_opened () {
        return opened;
    }

    public void toggle () {
        if (is_opened ()) {
            close ();
        } else {
            open ();
        }
    }

    /**
     * {@inheritDoc}
     */
    public void open (HashTable<string,Variant>? hints = null) {
        window_ids = hints != null && "windows" in hints ? (uint64[]) hints["windows"] : null;
        opened = true;
        last_selected_window = null;
        visible = true;

        wm.window_group.hide ();
        wm.top_window_group.hide ();
        grab_key_focus ();

        if (modal_proxy == null) {
            modal_proxy = wm.push_modal (this, true);
            modal_proxy.set_keybinding_filter (keybinding_filter);
            modal_proxy.allow_actions ({ ZOOM });
        }

        if (get_n_children () == 0) {
            var windows_number = 0u;

            unowned var display = wm.get_display ();
            for (var i = 0; i < display.get_n_monitors (); i++) {
                var geometry = display.get_monitor_geometry (i);
                var scale = display.get_monitor_scale (i);

                var custom_filter = new Gtk.CustomFilter (window_filter_func);
                var model = new WindowListModel (display, STACKING, true, i, null, custom_filter);
                model.items_changed.connect (on_items_changed);

                windows_number += model.get_n_items ();

                window_clone_container = new WindowCloneContainer (wm, model, scale, true) {
                    padding_top = TOP_GAP,
                    padding_left = BORDER,
                    padding_right = BORDER,
                    padding_bottom = BOTTOM_GAP,
                    width = geometry.width,
                    height = geometry.height,
                    x = geometry.x,
                    y = geometry.y,
                };
                window_clone_container.window_selected.connect (thumb_selected);
                window_clone_container.requested_close.connect (() => close ());

                add_child (window_clone_container);
            }

            if (windows_number == 0) {
                cleanup ();
                return;
            }
        }

        gesture_controller.goto (1);
    }

    private bool keybinding_filter (Meta.KeyBinding binding) {
        var action = Meta.Prefs.get_keybinding_action (binding.get_name ());

        switch (action) {
            case Meta.KeyBindingAction.NONE:
            case Meta.KeyBindingAction.LOCATE_POINTER_KEY:
                return false;
            default:
                break;
        }

        switch (binding.get_name ()) {
            case "expose-all-windows":
                return false;
            default:
                break;
        }

        return true;
    }

    private bool window_filter_func (Object obj) requires (obj is Meta.Window) {
        var window = (Meta.Window) obj;
        return window_ids == null || (window.get_id () in window_ids);
    }

    private void on_items_changed (ListModel model, uint pos, uint removed, uint added) {
        // Check removed > added to make sure we only close once when the last window is removed
        // This avoids an infinite loop since closing will sort the windows which also triggers this signal
        if (is_opened () && removed > added && model.get_n_items () == 0) {
            close ();
        }
    }

    private void thumb_selected (Meta.Window window) {
        if (window.get_workspace () == wm.get_display ().get_workspace_manager ().get_active_workspace ()) {
            window.activate (window.get_display ().get_current_time ());
        } else {
            last_selected_window = window;
        }

        close ();
    }

    /**
     * {@inheritDoc}
     */
    public void close (HashTable<string,Variant>? hints = null) {
        opened = false;
        gesture_controller.goto (0);
    }

    private void cleanup () {
        visible = false;
        opened = false;

        wm.window_group.show ();
        wm.top_window_group.show ();

        if (modal_proxy != null) {
            wm.pop_modal (modal_proxy);
        }

        destroy_all_children ();
    }
}
