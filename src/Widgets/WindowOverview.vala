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

    private ModalProxy modal_proxy;
    // the workspaces which we expose right now
    private List<Meta.Workspace> workspaces;

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

        add_action (new FocusController (wm.stage));
    }

    public override bool key_press_event (Clutter.Event event) {
        switch (event.get_key_symbol ()) {
            case Clutter.Key.Escape:
            case Clutter.Key.Return:
            case Clutter.Key.KP_Enter:
                close ();
                return Clutter.EVENT_STOP;
            default:
                return Clutter.EVENT_PROPAGATE;
        }
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
        workspaces = new List<Meta.Workspace> ();
        unowned var manager = wm.get_display ().get_workspace_manager ();
        foreach (unowned var workspace in manager.get_workspaces ()) {
            workspaces.append (workspace);
        }

        window_ids = hints != null && "windows" in hints ? (uint64[]) hints["windows"] : null;

        var windows = new List<Meta.Window> ();
        foreach (var workspace in workspaces) {
            foreach (unowned var window in workspace.list_windows ()) {
                if (window.window_type == Meta.WindowType.DOCK || NotificationStack.is_notification (window) ) {
                    continue;
                }

                if (window.window_type != Meta.WindowType.NORMAL &&
                    window.window_type != Meta.WindowType.DIALOG ||
                    window.is_attached_dialog () ||
                    (window_ids != null && !(window.get_id () in window_ids))
                ) {
                    unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
                    actor.hide ();

                    continue;
                }

                // skip windows that are on all workspace except we're currently
                // processing the workspace it actually belongs to
                if (window.on_all_workspaces && window.get_workspace () != workspace) {
                    continue;
                }

                windows.append (window);
            }
        }

        if (windows.is_empty ()) {
            return;
        }

        grab_key_focus ();

        modal_proxy = wm.push_modal (this, true);
        modal_proxy.set_keybinding_filter (keybinding_filter);
        modal_proxy.allow_actions ({ ZOOM });

        unowned var display = wm.get_display ();

        var mode = window_ids != null ? WindowClone.Mode.SINGLE_APP_OVERVIEW : WindowClone.Mode.OVERVIEW;

        for (var i = 0; i < display.get_n_monitors (); i++) {
            var geometry = display.get_monitor_geometry (i);
            var scale = Utils.get_ui_scaling_factor (display, i);

            var custom_filter = new Gtk.CustomFilter (window_filter_func);
            var model = new WindowListModel (display, STACKING, true, i, null, custom_filter);
            model.items_changed.connect (on_items_changed);

            var window_clone_container = new WindowCloneContainer (wm, model, scale, mode) {
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

            add_child (window_clone_container);
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

#if HAS_MUTTER48
        GLib.Timeout.add (MultitaskingView.ANIMATION_DURATION, () => {
#else
        Clutter.Threads.Timeout.add (MultitaskingView.ANIMATION_DURATION, () => {
#endif
            cleanup ();

            return Source.REMOVE;
        });

        gesture_controller.goto (0);
    }

    private void cleanup () {
        visible = false;

        wm.pop_modal (modal_proxy);

        foreach (var window in wm.get_display ().get_workspace_manager ().get_active_workspace ().list_windows ()) {
            if (window.showing_on_its_workspace ()) {
                ((Clutter.Actor) window.get_compositor_private ()).show ();
            }
        }

        destroy_all_children ();
    }
}
