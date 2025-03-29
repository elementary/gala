/*
 * Copyright 2012 Tom Beckmann
 * Copyright 2012 Rico Tzschichholz
 * Copyright 2023-2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowOverview : ActorTarget, RootTarget, ActivatableComponent {
    private const int BORDER = 10;
    private const int TOP_GAP = 30;
    private const int BOTTOM_GAP = 100;

    public Clutter.Actor? actor { get { return this; } }
    public WindowManager wm { get; construct; }

    private GestureController gesture_controller; // Currently not used for actual touchpad gestures but only as controller

    private Clutter.Actor background;
    private Clutter.Actor monitors;
    private ModalProxy modal_proxy;

    private uint64[]? window_ids = null;

    public WindowOverview (WindowManager wm) {
        Object (wm : wm);
    }

    construct {
        visible = false;
        reactive = true;
        gesture_controller = new GestureController (MULTITASKING_VIEW, wm) {
            enabled = false
        };
        add_gesture_controller (gesture_controller);

        background = new Clutter.Actor () {
#if HAS_MUTTER47
            background_color = Cogl.Color.from_string ("black")
#else
            background_color = Clutter.Color.from_string ("black")
#endif
        };
        background.add_constraint (new Clutter.BindConstraint (this, SIZE, 0));
        add_child (background);

        add_target (new PropertyTarget (MULTITASKING_VIEW, background, "opacity", typeof (uint), 0u, 150u));

        monitors = new ActorTarget ();
        add_child (monitors);
    }

    public override bool key_press_event (Clutter.Event event) {
        if (!is_opened ()) {
            return Clutter.EVENT_PROPAGATE;
        }

        //TODO: Navigating between monitors
        return get_child_at_index (wm.get_display ().get_primary_monitor ()).key_press_event (event);
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
        return visible;
    }

    /**
     * {@inheritDoc}
     */
    public void open (HashTable<string,Variant>? hints = null) {
        if (visible) {
            return;
        }

        window_ids = hints != null && "windows" in hints ? (uint64[]) hints["windows"] : null;

        var windows = new List<Meta.Window> ();
#if HAS_MUTTER48
        foreach (unowned var window_actor in wm.get_display ().get_compositor ().get_window_actors ()) {
#else
        foreach (unowned var window_actor in wm.get_display ().get_window_actors ()) {
#endif
            var window = window_actor.meta_window;
            if (ShellClientsManager.get_instance ().is_positioned_window (window) ||
                window.window_type != NORMAL && window.window_type != DIALOG ||
                window.is_attached_dialog () ||
                window_ids != null && !(window.get_id () in window_ids)
            ) {
                continue;
            }

            windows.append (window);
        }

        if (windows.is_empty ()) {
            return;
        }

        grab_key_focus ();

        modal_proxy = wm.push_modal (this, true);
        modal_proxy.set_keybinding_filter (keybinding_filter);
        modal_proxy.allow_actions ({ ZOOM });

        unowned var display = wm.get_display ();

        for (var i = 0; i < display.get_n_monitors (); i++) {
            var geometry = display.get_monitor_geometry (i);
            var scale = display.get_monitor_scale (i);

            var custom_filter = new Gtk.CustomFilter (window_filter_func);
            var model = new WindowListModel (display, STACKING, true, i, null, custom_filter);
            model.items_changed.connect (on_items_changed);

            var window_clone_container = new WindowCloneContainer (wm, model, scale, true) {
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

            monitors.add_child (window_clone_container);
        }

        visible = true;

        foreach (unowned var window in windows) {
            unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
            actor.hide ();
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
        // This avoids an inifinite loop since closing will sort the windows which also triggers this signal
        if (is_opened () && removed > added && model.get_n_items () == 0) {
            close ();
        }
    }

    private void thumb_selected (Meta.Window window) {
        if (window.get_workspace () == wm.get_display ().get_workspace_manager ().get_active_workspace ()) {
            window.activate (window.get_display ().get_current_time ());
            close ();
        } else {
            close ();

            // wait for the animation to finish before switching
            Timeout.add (MultitaskingView.ANIMATION_DURATION, () => {
                window.get_workspace ().activate_with_focus (window, window.get_display ().get_current_time ());
                return Source.REMOVE;
            });
        }
    }

    /**
     * {@inheritDoc}
     */
    public void close (HashTable<string,Variant>? hints = null) {
        if (!visible) {
            return;
        }

        gesture_controller.goto (0);
    }

    public override void end_progress (GestureAction action) {
        if (action != MULTITASKING_VIEW || get_current_commit (MULTITASKING_VIEW) > 0.5) {
            return;
        }

        visible = false;

        wm.pop_modal (modal_proxy);

        foreach (var window in wm.get_display ().get_workspace_manager ().get_active_workspace ().list_windows ()) {
            if (window.showing_on_its_workspace ()) {
                ((Clutter.Actor) window.get_compositor_private ()).show ();
            }
        }

        monitors.remove_all_children ();
    }
}
