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
public class Gala.MultitaskingView : ActorTarget, ActivatableComponent {
    public const int ANIMATION_DURATION = 250;

    private GestureController workspaces_gesture_controller;
    private GestureController multitasking_gesture_controller;

    public WindowManagerGala wm { get; construct; }

    private Meta.Display display;
    private ModalProxy modal_proxy;
    private bool opened = false;

    private List<MonitorClone> window_containers_monitors;

    private IconGroupContainer icon_groups;
    private ActorTarget workspaces;
    private Clutter.Actor primary_monitor_container;
    private Clutter.BrightnessContrastEffect brightness_effect;

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

        multitasking_gesture_controller = new GestureController (MULTITASKING_VIEW, this, wm);
        multitasking_gesture_controller.enable_touchpad ();

        add_target (ShellClientsManager.get_instance ()); // For hiding the panels

        workspaces = new WorkspaceRow (display);

        workspaces_gesture_controller = new GestureController (SWITCH_WORKSPACE, this, wm) {
            overshoot_upper_clamp = 0.1
        };
        workspaces_gesture_controller.enable_touchpad ();
        workspaces_gesture_controller.enable_scroll (this, HORIZONTAL);

        icon_groups = new IconGroupContainer (display.get_monitor_scale (display.get_primary_monitor ()));

        brightness_effect = new Clutter.BrightnessContrastEffect ();
        update_brightness_effect ();

        var blurred_bg = new BackgroundManager (display, display.get_primary_monitor (), true, false);
        blurred_bg.add_effect (new BlurEffect (blurred_bg, 18));
        blurred_bg.add_effect (brightness_effect);

        add_child (blurred_bg);

        // Create a child container that will be sized to fit the primary monitor, to contain the "main"
        // multitasking view UI. The Clutter.Actor of this class has to be allowed to grow to the size of the
        // stage as it contains MonitorClones for each monitor.
        primary_monitor_container = new ActorTarget ();
        primary_monitor_container.add_child (icon_groups);
        primary_monitor_container.add_child (workspaces);
        add_child (primary_monitor_container);

        add_child (StaticWindowContainer.get_instance (display));

        unowned var manager = display.get_workspace_manager ();
        manager.workspace_added.connect (add_workspace);
        manager.workspace_removed.connect (remove_workspace);
        manager.workspaces_reordered.connect (on_workspaces_reordered);
        manager.workspace_switched.connect (on_workspace_switched);

        manager.bind_property (
            "n-workspaces",
            workspaces_gesture_controller,
            "overshoot-lower-clamp",
            DEFAULT,
            (binding, from_value, ref to_value) => {
                to_value.set_double (-from_value.get_int () - 0.1 + 1);
            }
        );

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

    private void update_brightness_effect () {
        if (style_manager.prefers_color_scheme == DARK) {
            brightness_effect.set_brightness (-0.4f);
        } else {
            brightness_effect.set_brightness (0.4f);
        }
    }

    /**
     * Places the primary container for the WorkspaceClones and the
     * MonitorClones at the right positions
     */
    private void update_monitors () {
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

                var monitor_clone = new MonitorClone (wm, monitor);
                monitor_clone.window_selected.connect (window_selected);
                monitor_clone.visible = opened;

                window_containers_monitors.append (monitor_clone);
                add_child (monitor_clone);
            }
        }

        var primary_geometry = display.get_monitor_geometry (primary);
        var scale = display.get_monitor_scale (primary);
        icon_groups.scale_factor = scale;

        primary_monitor_container.set_position (primary_geometry.x, primary_geometry.y);
        primary_monitor_container.set_size (primary_geometry.width, primary_geometry.height);

        foreach (unowned var child in workspaces.get_children ()) {
            unowned var workspace_clone = (WorkspaceClone) child;
            workspace_clone.scale_factor = scale;
            workspace_clone.update_size (primary_geometry);
        }
    }

    private void update_workspaces () {
        foreach (unowned var child in workspaces.get_children ()) {
            unowned var workspace_clone = (WorkspaceClone) child;
            icon_groups.remove_group (workspace_clone.icon_group);
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
            grab_key_focus ();

            modal_proxy = wm.push_modal (this);
            modal_proxy.set_keybinding_filter (keybinding_filter);
            modal_proxy.allow_actions ({ MULTITASKING_VIEW, SWITCH_WORKSPACE, ZOOM });

            var scale = display.get_monitor_scale (display.get_primary_monitor ());
            icon_groups.force_reposition ();
            icon_groups.y = primary_monitor_container.height - InternalUtils.scale_to_int (WorkspaceClone.BOTTOM_OFFSET - 20, scale);
            reposition_icon_groups (false);

            if (action != MULTITASKING_VIEW) {
                icon_groups.hide ();
            }
        } else if (action == MULTITASKING_VIEW) {
            DragDropAction.cancel_all_by_id ("multitaskingview-window");
        }

        if (action == SWITCH_WORKSPACE) {
            WorkspaceManager.get_default ().freeze_remove ();

            if (workspaces_gesture_controller.action_info != null
                && (bool) workspaces_gesture_controller.action_info
                && display.focus_window != null
            ) {
                var moving = display.focus_window;

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
            icon_groups.show ();
            hide ();

            wm.pop_modal (modal_proxy);
        }

        if (action == SWITCH_WORKSPACE) {
            WorkspaceManager.get_default ().thaw_remove ();
            StaticWindowContainer.get_instance (display).notify_move_ended ();
            display.get_workspace_manager ().notify_property ("n-workspaces"); //Recalc overshoot bounds
        }
    }

    private void reposition_icon_groups (bool animate) {
        unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
        var active_index = manager.get_active_workspace ().index ();

        if (animate) {
            icon_groups.save_easing_state ();
            icon_groups.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            icon_groups.set_easing_duration (200);
        }

        var scale = display.get_monitor_scale (display.get_primary_monitor ());
        // make sure the active workspace's icongroup is always visible
        var icon_groups_width = icon_groups.calculate_total_width ();
        if (icon_groups_width > primary_monitor_container.width) {
            icon_groups.x = (-active_index * InternalUtils.scale_to_int (IconGroupContainer.SPACING + IconGroup.SIZE, scale) + primary_monitor_container.width / 2)
                .clamp (primary_monitor_container.width - icon_groups_width - InternalUtils.scale_to_int (64, scale), InternalUtils.scale_to_int (64, scale));
        } else
            icon_groups.x = primary_monitor_container.width / 2 - icon_groups_width / 2;

        if (animate) {
            icon_groups.restore_easing_state ();
        }
    }

    private void add_workspace (int num) {
        unowned var manager = display.get_workspace_manager ();
        var scale = display.get_monitor_scale (display.get_primary_monitor ());

        var workspace = new WorkspaceClone (wm, manager.get_workspace_by_index (num), scale);
        workspaces.insert_child_at_index (workspace, num);
        icon_groups.add_group (workspace.icon_group);

        workspace.window_selected.connect (window_selected);
        workspace.selected.connect (activate_workspace);

        reposition_icon_groups (false);
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
        workspace.selected.disconnect (activate_workspace);

        if (icon_groups.contains (workspace.icon_group)) {
            icon_groups.remove_group (workspace.icon_group);
        }

        workspace.destroy ();

        reposition_icon_groups (opened);

        workspaces_gesture_controller.progress = -manager.get_active_workspace_index ();
    }

    private void on_workspaces_reordered () {
        if (!visible) {
            unowned var manager = display.get_workspace_manager ();
            workspaces_gesture_controller.progress = -manager.get_active_workspace_index ();
        }

        reposition_icon_groups (false);
    }

    private void on_workspace_switched (int from, int to) {
        if ((int) (-get_current_commit (SWITCH_WORKSPACE)) != to) {
            workspaces_gesture_controller.goto (-to);
        }
    }

    /**
     * Activates the workspace of a WorkspaceClone
     *
     * @param close_view Whether to close the view as well. Will only be considered
     *                   if the workspace is also the currently active workspace.
     *                   Otherwise it will only be made active, but the view won't be
     *                   closed.
     */
    private void activate_workspace (WorkspaceClone clone, bool close_view) {
        unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
        close_view = close_view && manager.get_active_workspace () == clone.workspace;

        clone.workspace.activate (display.get_current_time ());

        if (close_view) {
            close ();
        }
    }

    /**
     * Collect key events, mainly for redirecting them to the WindowCloneContainers to
     * select the active window.
     */
    public override bool key_press_event (Clutter.Event event) {
        if (!opened) {
            return Clutter.EVENT_PROPAGATE;
        }

        return get_active_window_clone_container ().key_press_event (event);
    }

    /**
     * Finds the active WorkspaceClone
     *
     * @return The active WorkspaceClone
     */
    private WindowCloneContainer get_active_window_clone_container () {
        unowned var manager = display.get_workspace_manager ();
        unowned var active_workspace = manager.get_active_workspace ();
        foreach (unowned var child in workspaces.get_children ()) {
            unowned var workspace_clone = (WorkspaceClone) child;
            if (workspace_clone.workspace == active_workspace) {
                return workspace_clone.window_container;
            }
        }

        assert_not_reached ();
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
