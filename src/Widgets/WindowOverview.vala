/*
 * Copyright 2012 Tom Beckmann
 * Copyright 2012 Rico Tzschichholz
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowOverview : Clutter.Actor, ActivatableComponent {
    private const int BORDER = 10;
    private const int TOP_GAP = 30;
    private const int BOTTOM_GAP = 100;

    public WindowManager wm { get; construct; }

    private ModalProxy modal_proxy;

    // the workspaces which we expose right now
    private List<Meta.Workspace> workspaces;

    public WindowOverview (WindowManager wm) {
        Object (wm : wm);
    }

    construct {
        visible = false;
        reactive = true;
    }

    public override bool key_press_event (Clutter.KeyEvent event) {
        if (event.keyval == Clutter.Key.Escape) {
            close ();

            return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    public override void key_focus_out () {
        if (!contains (get_stage ().key_focus)) {
            close ();
        }
    }

    public override bool button_release_event (Clutter.ButtonEvent event) {
        if (event.button == Gdk.BUTTON_PRIMARY) {
            close ();
        }

        return Gdk.EVENT_STOP;
    }

    /**
     * {@inheritDoc}
     */
    public bool is_opened () {
        return visible;
    }

    /**
     * {@inheritDoc}
     * You may specify 'all-windows' in hints to expose all windows
     */
    public void open (HashTable<string,Variant>? hints = null) {
        var all_windows = hints != null && "all-windows" in hints;

        workspaces = new List<Meta.Workspace> ();
        unowned var manager = wm.get_display ().get_workspace_manager ();
        if (all_windows) {
            foreach (unowned var workspace in manager.get_workspaces ()) {
                workspaces.append (workspace);
            }
        } else {
            workspaces.append (manager.get_active_workspace ());
        }

        var windows = new List<Meta.Window> ();
        foreach (var workspace in workspaces) {
            foreach (unowned var window in workspace.list_windows ()) {
                if (window.window_type == Meta.WindowType.DOCK
                    || window.window_type == Meta.WindowType.NOTIFICATION) {
                    continue;
                }

                if (window.window_type != Meta.WindowType.NORMAL &&
                    window.window_type != Meta.WindowType.DIALOG ||
                    window.is_attached_dialog ()) {
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

        foreach (var workspace in workspaces) {
            workspace.window_added.connect (add_window);
            workspace.window_removed.connect (remove_window);
        }

        wm.get_display ().window_left_monitor.connect (window_left_monitor);

        grab_key_focus ();

        modal_proxy = wm.push_modal (this);
        modal_proxy.set_keybinding_filter (keybinding_filter);

        for (var i = 0; i < wm.get_display ().get_n_monitors (); i++) {
            var geometry = wm.get_display ().get_monitor_geometry (i);

            var container = new WindowCloneContainer (wm, null, true) {
                padding_top = TOP_GAP,
                padding_left = BORDER,
                padding_right = BORDER,
                padding_bottom = BOTTOM_GAP
            };
            container.set_position (geometry.x, geometry.y);
            container.set_size (geometry.width, geometry.height);
            container.window_selected.connect (thumb_selected);

            add_child (container);
        }

        visible = true;

        foreach (unowned var window in windows) {
            unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
            actor.hide ();

            unowned var container = (WindowCloneContainer) get_child_at_index (window.get_monitor ());
            if (container == null) {
                continue;
            }

            container.add_window (window);
            container.open ();
        }
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
            case "expose-windows":
            case "expose-all-windows":
            case "zoom-in":
            case "zoom-out":
                return false;
            default:
                break;
        }

        return true;
    }

    private void restack_windows () {
        foreach (var child in get_children ()) {
            ((WindowCloneContainer) child).restack_windows ();
        }
    }

    private void window_left_monitor (int num, Meta.Window window) {
        unowned var container = (WindowCloneContainer) get_child_at_index (num);
        if (container == null) {
            return;
        }

        // make sure the window belongs to one of our workspaces
        foreach (var workspace in workspaces) {
            if (window.located_on_workspace (workspace)) {
                container.remove_window (window);
                break;
            }
        }
    }

    private void add_window (Meta.Window window) {
        if (!visible) {
            return;
        }
        if (window.window_type == Meta.WindowType.DOCK
            || window.window_type == Meta.WindowType.NOTIFICATION) {
            return;
        }
        if (window.window_type != Meta.WindowType.NORMAL &&
            window.window_type != Meta.WindowType.DIALOG ||
            window.is_attached_dialog ()) {
            unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
            actor.hide ();

            return;
        }

        unowned var container = (WindowCloneContainer) get_child_at_index (window.get_monitor ());
        if (container == null) {
            return;
        }

        // make sure the window belongs to one of our workspaces
        foreach (var workspace in workspaces) {
            if (window.located_on_workspace (workspace)) {
                container.add_window (window);
                break;
            }
        }
    }

    private void remove_window (Meta.Window window) {
        unowned var container = (WindowCloneContainer) get_child_at_index (window.get_monitor ());
        if (container == null) {
            return;
        }

        container.remove_window (window);
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

        restack_windows ();

        foreach (var workspace in workspaces) {
            workspace.window_added.disconnect (add_window);
            workspace.window_removed.disconnect (remove_window);
        }
        wm.get_display ().window_left_monitor.disconnect (window_left_monitor);

        foreach (unowned var child in get_children ()) {
            ((WindowCloneContainer) child).close ();
        }

        Clutter.Threads.Timeout.add (MultitaskingView.ANIMATION_DURATION, () => {
            cleanup ();

            return Source.REMOVE;
        });
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
