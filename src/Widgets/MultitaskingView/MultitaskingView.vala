//
//  Copyright (C) 2014 Tom Beckmann
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

/**
 * The central class for the MultitaskingView which takes care of
 * preparing the wm, opening the components and holds containers for
 * the icon groups, the WorkspaceClones and the MonitorClones.
 */
public class Gala.MultitaskingView : ActorTarget, RootTarget, ActivatableComponent {
    public const int ANIMATION_DURATION = 250;

    private GestureController workspaces_gesture_controller;
    private GestureController multitasking_gesture_controller;

    public Clutter.Actor? actor { get { return this; } }
    public WindowManagerGala wm { get; construct; }

    private Meta.Display display;
    private ModalProxy modal_proxy;
    private bool opened = false;

    private List<MonitorClone> window_containers_monitors;

    private ActorTarget workspaces;
    private Clutter.Actor primary_monitor_container;
    private Clutter.BrightnessContrastEffect brightness_effect;
    private BackgroundManager? blurred_bg = null;

    private GLib.Settings gala_behavior_settings;
    private Drawing.StyleManager style_manager;

    public MultitaskingView (WindowManagerGala wm) {
        Object (wm: wm);
    }

    construct {
        gala_behavior_settings = new GLib.Settings ("io.elementary.desktop.wm.behavior");
        style_manager = Drawing.StyleManager.get_instance ();

        visible = false;
        reactive = true;
        clip_to_allocation = true;

        opened = false;
        display = wm.get_display ();

        add_action (new FocusController (wm.stage));

        multitasking_gesture_controller = new GestureController (MULTITASKING_VIEW, wm, MULTITASKING_VIEW);
        multitasking_gesture_controller.enable_touchpad (wm.stage);
        add_gesture_controller (multitasking_gesture_controller);

        add_target (ShellClientsManager.get_instance ()); // For hiding the panels

        workspaces = new WorkspaceRow (display);

        workspaces_gesture_controller = new GestureController (SWITCH_WORKSPACE, wm, MULTITASKING_VIEW) {
            overshoot_upper_clamp = 0.1,
            follow_natural_scroll = true,
        };
        workspaces_gesture_controller.enable_touchpad (wm.stage);
        workspaces_gesture_controller.enable_scroll (this, HORIZONTAL);
        add_gesture_controller (workspaces_gesture_controller);

        update_blurred_bg ();

        // Create a child container that will be sized to fit the primary monitor, to contain the "main"
        // multitasking view UI. The Clutter.Actor of this class has to be allowed to grow to the size of the
        // stage as it contains MonitorClones for each monitor.
        primary_monitor_container = new ActorTarget ();
        primary_monitor_container.add_child (workspaces);
        add_child (primary_monitor_container);

        add_child (StaticWindowContainer.get_instance (display));

        unowned var manager = display.get_workspace_manager ();
        manager.workspace_added.connect (add_workspace);
        manager.workspace_removed.connect (remove_workspace);
        manager.workspaces_reordered.connect (on_workspaces_reordered);
        manager.workspace_switched.connect (on_workspace_switched);

        workspaces_gesture_controller.overshoot_lower_clamp = -manager.n_workspaces - 0.1 + 1;
        manager.notify["n-workspaces"].connect (() => {
            workspaces_gesture_controller.overshoot_lower_clamp = -manager.n_workspaces - 0.1 + 1;
        });

        window_containers_monitors = new List<MonitorClone> ();
        update_monitors ();
        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_monitors);

        Meta.Prefs.add_listener ((pref) => {
            if (pref == Meta.Preference.WORKSPACES_ONLY_ON_PRIMARY) {
                update_monitors ();
            }
        });

        style_manager.notify["prefers-color-scheme"].connect (update_brightness_effect);
    }

    /**
     * Places the primary container for the WorkspaceClones and the
     * MonitorClones at the right positions
     */
    private void update_monitors () {
        update_blurred_bg ();
        update_workspaces ();

        foreach (var monitor_clone in window_containers_monitors) {
            monitor_clone.destroy ();
        }

        var primary = display.get_primary_monitor ();

        if (Meta.Prefs.get_workspaces_only_on_primary ()) {
            for (var monitor = 0; monitor < display.get_n_monitors (); monitor++) {
                if (monitor == primary) {
                    continue;
                }

                var monitor_clone = new MonitorClone (wm, monitor) {
                    visible = true
                };
                monitor_clone.window_selected.connect (window_selected);

                window_containers_monitors.append (monitor_clone);
                add_child (monitor_clone);
            }
        }

        var primary_geometry = display.get_monitor_geometry (primary);
        var scale = Utils.get_ui_scaling_factor (display, primary);

        primary_monitor_container.set_position (primary_geometry.x, primary_geometry.y);
        primary_monitor_container.set_size (primary_geometry.width, primary_geometry.height);

        foreach (unowned var child in workspaces.get_children ()) {
            unowned var workspace_clone = (WorkspaceClone) child;
            workspace_clone.monitor_scale = scale;
            workspace_clone.update_size (primary_geometry);
        }
    }

    private void update_brightness_effect () {
        if (style_manager.prefers_color_scheme == DARK) {
            brightness_effect.set_brightness (-0.4f);
        } else {
            brightness_effect.set_brightness (0.4f);
        }
    }

    private void update_blurred_bg () {
        if (blurred_bg != null) {
            remove_child (blurred_bg);
        }

        brightness_effect = new Clutter.BrightnessContrastEffect ();
        update_brightness_effect ();

        blurred_bg = new BackgroundManager (display, display.get_primary_monitor (), true, false);
        blurred_bg.add_effect (new BlurEffect (blurred_bg, 18));
        blurred_bg.add_effect (brightness_effect);

        insert_child_below (blurred_bg, null);
    }

    private void update_workspaces () {
        foreach (unowned var child in workspaces.get_children ()) {
            unowned var workspace_clone = (WorkspaceClone) child;
            workspace_clone.destroy ();
        }

        unowned var manager = display.get_workspace_manager ();
        for (int i = 0; i < manager.get_n_workspaces (); i++) {
            add_workspace (i);
        }
    }

    /**
     * Scroll through workspaces with the mouse wheel. Smooth scrolling is handled by
     * GestureController.
     */
    public override bool scroll_event (Clutter.Event scroll_event) {
        if (!opened) {
            return true;
        }

        Clutter.ScrollDirection scroll_direction = scroll_event.get_scroll_direction ();
        if (scroll_direction == Clutter.ScrollDirection.SMOOTH ||
            scroll_event.get_scroll_source () == Clutter.ScrollSource.FINGER ||
            scroll_event.get_source_device ().get_device_type () == Clutter.InputDeviceType.TOUCHPAD_DEVICE) {
            return false;
        }

        Meta.MotionDirection direction;
        switch (scroll_direction) {
            case Clutter.ScrollDirection.UP:
            case Clutter.ScrollDirection.LEFT:
                direction = Meta.MotionDirection.LEFT;
                break;
            case Clutter.ScrollDirection.DOWN:
            case Clutter.ScrollDirection.RIGHT:
            default:
                direction = Meta.MotionDirection.RIGHT;
                break;
        }

        switch_to_next_workspace (direction);

        return true;
    }

    public void move_window (Meta.Window window, Meta.Workspace workspace) {
        StaticWindowContainer.get_instance (display).notify_window_moving (window);
        workspaces_gesture_controller.goto (-workspace.index ());
    }

    public void switch_to_next_workspace (Meta.MotionDirection direction) {
        var relative_direction = direction == LEFT ? 1 : -1;
        workspaces_gesture_controller.goto (get_current_commit (SWITCH_WORKSPACE) + relative_direction);
    }

    public void kill_switch_workspace () {
        // Not really a kill (we let the animation finish)
        // but since we only use clones that's ok
        workspaces_gesture_controller.cancel_gesture ();
    }

    public override void start_progress (GestureAction action) {
        if (!visible) {
            opened = true;

            wm.background_group.hide ();
            wm.window_group.hide ();
            wm.top_window_group.hide ();
            show ();

            modal_proxy = wm.push_modal (get_stage (), false);
            modal_proxy.set_keybinding_filter (keybinding_filter);
            modal_proxy.allow_actions ({ MULTITASKING_VIEW, SWITCH_WORKSPACE, ZOOM });
        } else if (action == MULTITASKING_VIEW) {
            DragDropAction.cancel_all_by_id ("multitaskingview-window");
        }

        if (action == SWITCH_WORKSPACE) {
            WorkspaceManager.get_default ().freeze_remove ();

            var mru_window = InternalUtils.get_mru_window (display.get_workspace_manager ().get_active_workspace ());

            if (workspaces_gesture_controller.action_info != null
                && (bool) workspaces_gesture_controller.action_info
                && mru_window != null
            ) {
                var moving = mru_window;

                StaticWindowContainer.get_instance (display).notify_window_moving (moving);

                // Prevent moving to the last workspace if second last would be empty
                if (moving.get_workspace ().index () == display.get_workspace_manager ().n_workspaces - 2 &&
                    Utils.get_n_windows (moving.get_workspace (), true, moving) == 0
                ) {
                    workspaces_gesture_controller.overshoot_lower_clamp += 1;
                }
            }
        }
    }

    public override void commit_progress (GestureAction action, double to) {
        switch (action) {
            case MULTITASKING_VIEW:
                opened = to > 0.5 || workspaces_gesture_controller.recognizing;
                workspaces_gesture_controller.cancel_gesture ();
                break;

            case SWITCH_WORKSPACE:
                opened = get_current_commit (MULTITASKING_VIEW) > 0.5 || multitasking_gesture_controller.recognizing;
                unowned var target_workspace = display.get_workspace_manager ().get_workspace_by_index ((int) (-to));
                var moving_window = StaticWindowContainer.get_instance (display).moving_window;
                if (moving_window != null) {
                    moving_window.change_workspace (target_workspace);
                    target_workspace.activate_with_focus (moving_window, display.get_current_time ());
                } else {
                    target_workspace.activate (display.get_current_time ());
                }
                break;

            default:
                break;
        }
    }

    public override void end_progress (GestureAction action) {
        if (!opened && !animating) {
            wm.background_group.show ();
            wm.window_group.show ();
            wm.top_window_group.show ();
            hide ();

            wm.pop_modal (modal_proxy);
        }

        if (action == SWITCH_WORKSPACE) {
            WorkspaceManager.get_default ().thaw_remove ();
            StaticWindowContainer.get_instance (display).notify_move_ended ();
            display.get_workspace_manager ().notify_property ("n-workspaces"); //Recalc overshoot bounds
        }
    }

    private void add_workspace (int num) {
        unowned var manager = display.get_workspace_manager ();
        var scale = Utils.get_ui_scaling_factor (display, display.get_primary_monitor ());

        var workspace = new WorkspaceClone (wm, manager.get_workspace_by_index (num), scale);
        workspaces.insert_child_at_index (workspace, num);

        workspace.window_selected.connect (window_selected);
    }

    private void remove_workspace (int num) {
        WorkspaceClone? workspace = null;

        // FIXME is there a better way to get the removed workspace?
        unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
        List<Meta.Workspace> existing_workspaces = null;
        for (int i = 0; i < manager.get_n_workspaces (); i++) {
            existing_workspaces.append (manager.get_workspace_by_index (i));
        }

        foreach (unowned var child in workspaces.get_children ()) {
            unowned var clone = (WorkspaceClone) child;
            if (existing_workspaces.index (clone.workspace) < 0) {
                workspace = clone;
                break;
            }
        }

        if (workspace == null) {
            return;
        }

        workspace.window_selected.disconnect (window_selected);
        workspace.destroy ();

        workspaces_gesture_controller.progress = -manager.get_active_workspace_index ();
    }

    private void on_workspaces_reordered () {
        unowned var manager = display.get_workspace_manager ();
        workspaces_gesture_controller.progress = -manager.get_active_workspace_index ();
    }

    private void on_workspace_switched (int from, int to) {
        if ((int) (-get_current_commit (SWITCH_WORKSPACE)) != to) {
            workspaces_gesture_controller.goto (-to);
        }
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

    private void window_selected (Meta.Window window) {
        var time = display.get_current_time ();
        unowned var manager = display.get_workspace_manager ();
        unowned var workspace = window.get_workspace ();

        if (workspace != manager.get_active_workspace ()) {
            workspace.activate (time);
        } else {
            window.activate (time);
            close ();
        }
    }

    /**
     * {@inheritDoc}
     */
    public bool is_opened () {
        return opened;
    }

    /**
     * {@inheritDoc}
     */
    public void open (HashTable<string,Variant>? hints = null) {
        multitasking_gesture_controller.goto (1);
    }

    /**
     * {@inheritDoc}
     */
    public void close (HashTable<string,Variant>? hints = null) {
        multitasking_gesture_controller.goto (0);
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
            case "screenshot":
            case "screenshot-clip":
                return false;
            default:
                break;
        }

        return true;
    }

    public override bool captured_event (Clutter.Event event) {
        /* If we aren't open but receive events this means we are animating closed
         * or we are finishing a workspace switch animation. In any case we want to
         * prevent a drag and drop to start for the window clones which can happen
         * pretty easily if you click on one while the animation finishes.
         */
        var type = event.get_type (); // LEAVE and ENTER have to be propagated
        if (!opened && animating && type != ENTER && type != LEAVE) {
            return Clutter.EVENT_STOP;
        }

        return Clutter.EVENT_PROPAGATE;
    }
}
