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

namespace Gala {
    /**
     * The central class for the MultitaskingView which takes care of
     * preparing the wm, opening the components and holds containers for
     * the icon groups, the WorkspaceClones and the MonitorClones.
     */
    public class MultitaskingView : Clutter.Actor, ActivatableComponent {
        public const int ANIMATION_DURATION = 250;
        private const string OPEN_MULTITASKING_VIEW = "dbus-send --session --dest=org.pantheon.gala --print-reply /org/pantheon/gala org.pantheon.gala.PerformAction int32:1";

        private GestureTracker multitasking_gesture_tracker;
        private GestureTracker workspace_gesture_tracker;

        public WindowManager wm { get; construct; }

        private Meta.Display display;
        private ModalProxy modal_proxy;
        private bool opened = false;
        private bool animating = false;

        private List<MonitorClone> window_containers_monitors;

        private IconGroupContainer icon_groups;
        private Clutter.Actor workspaces;
        private Clutter.Actor dock_clones;
        private Clutter.Actor primary_monitor_container;

        private GLib.Settings gala_behavior_settings;

        public MultitaskingView (WindowManager wm) {
            Object (wm: wm);
        }

        construct {
            gala_behavior_settings = new GLib.Settings ("org.pantheon.desktop.gala.behavior");

            visible = false;
            reactive = true;
            clip_to_allocation = true;

            opened = false;
            display = wm.get_display ();

            multitasking_gesture_tracker = new GestureTracker (ANIMATION_DURATION, ANIMATION_DURATION);
            multitasking_gesture_tracker.enable_touchpad ();
            multitasking_gesture_tracker.on_gesture_detected.connect (on_multitasking_gesture_detected);

            workspace_gesture_tracker = new GestureTracker (AnimationDuration.WORKSPACE_SWITCH_MIN, AnimationDuration.WORKSPACE_SWITCH);
            workspace_gesture_tracker.enable_touchpad ();
            workspace_gesture_tracker.enable_scroll (this, Clutter.Orientation.HORIZONTAL);
            workspace_gesture_tracker.on_gesture_detected.connect (on_workspace_gesture_detected);

            workspaces = new Clutter.Actor ();
            workspaces.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);

            icon_groups = new IconGroupContainer (wm, display.get_monitor_scale (display.get_primary_monitor ()));

            dock_clones = new Clutter.Actor ();

            // Create a child container that will be sized to fit the primary monitor, to contain the "main"
            // multitasking view UI. The Clutter.Actor of this class has to be allowed to grow to the size of the
            // stage as it contains MonitorClones for each monitor.
            primary_monitor_container = new Clutter.Actor ();
            primary_monitor_container.add_child (icon_groups);
            primary_monitor_container.add_child (workspaces);
            add_child (primary_monitor_container);
            add_child (dock_clones);

            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            for (int i = 0; i < manager.get_n_workspaces (); i++) {
                add_workspace (i);
            }

            manager.workspace_added.connect (add_workspace);
            manager.workspace_removed.connect (remove_workspace);
            manager.workspaces_reordered.connect (() => update_positions (false));
            manager.workspace_switched.connect_after ((from, to, direction) => {
                update_positions (opened);
            });

            window_containers_monitors = new List<MonitorClone> ();
            update_monitors ();
            unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
            monitor_manager.monitors_changed.connect (update_monitors);

            Meta.Prefs.add_listener ((pref) => {
                if (pref == Meta.Preference.WORKSPACES_ONLY_ON_PRIMARY) {
                    update_monitors ();
                    return;
                }

                if (Meta.Prefs.get_dynamic_workspaces () ||
                    (pref != Meta.Preference.DYNAMIC_WORKSPACES && pref != Meta.Preference.NUM_WORKSPACES))
                    return;

                Idle.add (() => {
                    unowned List<Meta.Workspace> existing_workspaces = null;
                    for (int i = 0; i < manager.get_n_workspaces (); i++) {
                        existing_workspaces.append (manager.get_workspace_by_index (i));
                    }

                    foreach (var child in workspaces.get_children ()) {
                        unowned WorkspaceClone workspace_clone = (WorkspaceClone) child;
                        if (existing_workspaces.index (workspace_clone.workspace) < 0) {
                            workspace_clone.window_selected.disconnect (window_selected);
                            workspace_clone.selected.disconnect (activate_workspace);

                            icon_groups.remove_group (workspace_clone.icon_group);

                            workspace_clone.destroy ();
                        }
                    }

                    update_monitors ();
                    update_positions (false);

                    return false;
                });
            });
        }

        /**
         * Places the primary container for the WorkspaceClones and the
         * MonitorClones at the right positions
         */
        private void update_monitors () {
            foreach (var monitor_clone in window_containers_monitors)
                monitor_clone.destroy ();

            var primary = display.get_primary_monitor ();

            if (InternalUtils.workspaces_only_on_primary ()) {
                for (var monitor = 0; monitor < display.get_n_monitors (); monitor++) {
                    if (monitor == primary)
                        continue;

                    var monitor_clone = new MonitorClone (wm, display, monitor, multitasking_gesture_tracker);
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

            foreach (var child in workspaces.get_children ()) {
                unowned WorkspaceClone workspace_clone = (WorkspaceClone) child;
                workspace_clone.scale_factor = scale;
                workspace_clone.update_size (primary_geometry);
            }
        }

        /**
         * Scroll through workspaces with the mouse wheel. Smooth scrolling is handled by
         * GestureTracker.
         */
        public override bool scroll_event (Clutter.ScrollEvent scroll_event) {
            if (!opened) {
                return true;
            }

            if (scroll_event.direction == Clutter.ScrollDirection.SMOOTH ||
                scroll_event.scroll_source == Clutter.ScrollSource.FINGER ||
                scroll_event.get_source_device ().get_device_type () == Clutter.InputDeviceType.TOUCHPAD_DEVICE) {
                return false;
            }

            Meta.MotionDirection direction;
            switch (scroll_event.direction) {
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

            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var active_workspace = manager.get_active_workspace ();
            var new_workspace = active_workspace.get_neighbor (direction);

            if (active_workspace != new_workspace) {
                new_workspace.activate (display.get_current_time ());
            } else {
                play_nudge_animation (direction);
            }

            return true;
        }

        public void play_nudge_animation (Meta.MotionDirection direction) {
            if (!wm.enable_animations) {
                return;
            }

            var scale = display.get_monitor_scale (display.get_primary_monitor ());
            var nudge_gap = InternalUtils.scale_to_int (WindowManagerGala.NUDGE_GAP, scale);

            float dest = nudge_gap;
            if (direction == Meta.MotionDirection.RIGHT) {
                dest *= -1;
            }

            double[] keyframes = { 0.5 };
            GLib.Value[] x = { dest };

            var nudge = new Clutter.KeyframeTransition ("translation-x") {
                duration = AnimationDuration.NUDGE,
                remove_on_complete = true,
                progress_mode = Clutter.AnimationMode.EASE_IN_QUAD
            };
            nudge.set_from_value (0.0f);
            nudge.set_to_value (0.0f);
            nudge.set_key_frames (keyframes);
            nudge.set_values (x);
            workspaces.add_transition ("nudge", nudge);
        }

        private void on_multitasking_gesture_detected (Gesture gesture) {
            if (gesture.type != Clutter.EventType.TOUCHPAD_SWIPE ||
                (gesture.fingers == 3 && GestureSettings.get_string ("three-finger-swipe-up") != "multitasking-view") ||
                (gesture.fingers == 4 && GestureSettings.get_string ("four-finger-swipe-up") != "multitasking-view")
            ) {
                return;
            }

            if (gesture.direction == GestureDirection.UP && !opened) {
                toggle (true, false);
            } else if (gesture.direction == GestureDirection.DOWN && opened) {
                toggle (true, false);
            }
        }

        private void on_workspace_gesture_detected (Gesture gesture) {
            if (!opened) {
                return;
            }

            var can_handle_swipe = gesture.type == Clutter.EventType.TOUCHPAD_SWIPE &&
                (gesture.direction == GestureDirection.LEFT || gesture.direction == GestureDirection.RIGHT);

            var fingers = (gesture.fingers == 3 && Gala.GestureSettings.get_string ("three-finger-swipe-horizontal") == "switch-to-workspace") ||
                (gesture.fingers == 4 && Gala.GestureSettings.get_string ("four-finger-swipe-horizontal") == "switch-to-workspace");

            if (gesture.type == Clutter.EventType.SCROLL || (can_handle_swipe && fingers)) {
                var direction = workspace_gesture_tracker.settings.get_natural_scroll_direction (gesture);
                switch_workspace_with_gesture (direction);
            }
        }

        private void switch_workspace_with_gesture (Meta.MotionDirection direction) {
            var relative_dir = (direction == Meta.MotionDirection.LEFT) ? -1 : 1;

            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var num_workspaces = manager.get_n_workspaces ();
            var active_workspace_index = manager.get_active_workspace ().index ();
            var target_workspace_index = active_workspace_index + relative_dir;

            float initial_x = workspaces.x;
            float target_x = 0;
            bool is_nudge_animation = (target_workspace_index < 0 || target_workspace_index >= num_workspaces);
            var scale = display.get_monitor_scale (display.get_primary_monitor ());
            var nudge_gap = InternalUtils.scale_to_int (WindowManagerGala.NUDGE_GAP, scale);

            unowned IconGroup active_icon_group = null;
            unowned IconGroup? target_icon_group = null;

            if (is_nudge_animation) {
                var workspaces_geometry = InternalUtils.get_workspaces_geometry (display);
                target_x = initial_x + (workspaces_geometry.width * -relative_dir);
            } else {
                foreach (unowned var child in workspaces.get_children ()) {
                    unowned var workspace_clone = (WorkspaceClone) child;
                    var index = workspace_clone.workspace.index ();

                    if (index == target_workspace_index) {
                        target_icon_group = workspace_clone.icon_group;
                        target_x = -workspace_clone.multitasking_view_x ();
                    } else if (index == active_workspace_index) {
                        active_icon_group = workspace_clone.icon_group;
                    }
                }
            }

            if (!is_nudge_animation && active_icon_group.get_transition ("backdrop-opacity") != null) {
                active_icon_group.remove_transition ("backdrop-opacity");
            }
            if (!is_nudge_animation && target_icon_group.get_transition ("backdrop-opacity") != null) {
                target_icon_group.remove_transition ("backdrop-opacity");
            }

            debug ("Starting MultitaskingView switch workspace animation:");
            debug ("Active workspace index: %d", active_workspace_index);
            debug ("Target workspace index: %d", target_workspace_index);
            debug ("Total number of workspaces: %d", num_workspaces);
            debug ("Is nudge animation: %s", is_nudge_animation ? "Yes" : "No");
            debug ("Initial X: %f", initial_x);
            debug ("Target X: %f", target_x);

            GestureTracker.OnUpdate on_animation_update = (percentage) => {
                var x = GestureTracker.animation_value (initial_x, target_x, percentage, true);
                var icon_group_opacity = GestureTracker.animation_value (0.0f, 1.0f, percentage, false);

                if (is_nudge_animation) {
                    x = x.clamp (initial_x - nudge_gap, initial_x + nudge_gap);
                }

                workspaces.x = x;

                if (!is_nudge_animation) {
                    active_icon_group.backdrop_opacity = 1.0f - icon_group_opacity;
                    target_icon_group.backdrop_opacity = icon_group_opacity;
                }
            };

            GestureTracker.OnEnd on_animation_end = (percentage, cancel_action, calculated_duration) => {
                workspace_gesture_tracker.enabled = false;

                var duration = is_nudge_animation ?
                               (uint) (AnimationDuration.NUDGE / 2) :
                               (uint) calculated_duration;

                workspaces.save_easing_state ();
                workspaces.set_easing_duration (duration);
                workspaces.x = (is_nudge_animation || cancel_action) ? initial_x : target_x;
                workspaces.restore_easing_state ();

                if (!is_nudge_animation) {
                    if (wm.enable_animations) {
                        var active_transition = new Clutter.PropertyTransition ("backdrop-opacity") {
                            duration = duration,
                            remove_on_complete = true
                        };
                        active_transition.set_from_value (active_icon_group.backdrop_opacity);
                        active_transition.set_to_value (cancel_action ? 1.0f : 0.0f);
                        active_icon_group.add_transition ("backdrop-opacity", active_transition);

                        var target_transition = new Clutter.PropertyTransition ("backdrop-opacity") {
                            duration = duration,
                            remove_on_complete = true
                        };
                        target_transition.set_from_value (target_icon_group.backdrop_opacity);
                        target_transition.set_to_value (cancel_action ? 0.0f : 1.0f);
                        target_icon_group.add_transition ("backdrop-opacity", target_transition);
                    } else {
                        active_icon_group.backdrop_opacity = cancel_action ? 1.0f : 0.0f;
                        target_icon_group.backdrop_opacity = cancel_action ? 0.0f : 1.0f;
                    }
                }


                var transition = workspaces.get_transition ("x");
                if (transition != null) {
                    transition.completed.connect (() => {
                        workspace_gesture_tracker.enabled = true;

                        if (!is_nudge_animation && !cancel_action) {
                            manager.get_workspace_by_index (target_workspace_index).activate (display.get_current_time ());
                            update_positions (false);
                        }
                    });
                } else {
                    workspace_gesture_tracker.enabled = true;

                    if (!is_nudge_animation && !cancel_action) {
                        manager.get_workspace_by_index (target_workspace_index).activate (display.get_current_time ());
                        update_positions (false);
                    }
                }
            };

            if (!wm.enable_animations) {
                on_animation_end (1, false, 0);
            } else {
                workspace_gesture_tracker.connect_handlers (null, (owned) on_animation_update, (owned) on_animation_end);
            }
        }

        /**
         * Places the WorkspaceClones, moves the view so that the active one is shown
         * and does the same for the IconGroups.
         *
         * @param animate Whether to animate the movement or have all elements take their
         *                positions immediately.
         */
        private void update_positions (bool animate) {
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var active_index = manager.get_active_workspace ().index ();
            var active_x = 0.0f;

            foreach (unowned var child in workspaces.get_children ()) {
                unowned var workspace_clone = (WorkspaceClone) child;
                var index = workspace_clone.workspace.index ();
                var dest_x = workspace_clone.multitasking_view_x ();

                if (index == active_index) {
                    active_x = dest_x;
                    workspace_clone.icon_group.backdrop_opacity = 1.0f;
                } else {
                    workspace_clone.icon_group.backdrop_opacity = 0.0f;
                }

                workspace_clone.save_easing_state ();
                workspace_clone.set_easing_duration ((animate && wm.enable_animations) ? 200 : 0);
                workspace_clone.x = dest_x;
                workspace_clone.restore_easing_state ();
            }

            workspaces.save_easing_state ();
            workspaces.set_easing_duration ((animate && wm.enable_animations) ? AnimationDuration.WORKSPACE_SWITCH_MIN : 0);
            workspaces.x = -active_x;
            workspaces.restore_easing_state ();

            reposition_icon_groups (animate);
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

            if (animate)
                icon_groups.restore_easing_state ();
        }

        private void add_workspace (int num) {
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var scale = display.get_monitor_scale (display.get_primary_monitor ());
            var workspace = new WorkspaceClone (wm, manager.get_workspace_by_index (num), multitasking_gesture_tracker, scale);
            workspace.window_selected.connect (window_selected);
            workspace.selected.connect (activate_workspace);

            workspaces.insert_child_at_index (workspace, num);
            icon_groups.add_group (workspace.icon_group);

            update_positions (false);

            if (opened)
                workspace.open ();
        }

        private void remove_workspace (int num) {
            WorkspaceClone? workspace = null;

            // FIXME is there a better way to get the removed workspace?
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            List<Meta.Workspace> existing_workspaces = null;
            for (int i = 0; i < manager.get_n_workspaces (); i++) {
                existing_workspaces.append (manager.get_workspace_by_index (i));
            }

            foreach (var child in workspaces.get_children ()) {
                unowned WorkspaceClone clone = (WorkspaceClone) child;
                if (existing_workspaces.index (clone.workspace) < 0) {
                    workspace = clone;
                    break;
                }
            }

            if (workspace == null)
                return;

            workspace.window_selected.disconnect (window_selected);
            workspace.selected.disconnect (activate_workspace);

            if (icon_groups.contains (workspace.icon_group)) {
                icon_groups.remove_group (workspace.icon_group);
            }

            workspace.destroy ();

            update_positions (opened);
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

            if (close_view)
                toggle ();
        }

        /**
         * Collect key events, mainly for redirecting them to the WindowCloneContainers to
         * select the active window.
         */
        public override bool key_press_event (Clutter.KeyEvent event) {
            if (!opened)
                return true;

            switch (event.keyval) {
                case Clutter.Key.Escape:
                    toggle ();
                    break;
                case Clutter.Key.Down:
                    select_window (Meta.MotionDirection.DOWN);
                    break;
                case Clutter.Key.Up:
                    select_window (Meta.MotionDirection.UP);
                    break;
                case Clutter.Key.Left:
                    select_window (Meta.MotionDirection.LEFT);
                    break;
                case Clutter.Key.Right:
                    select_window (Meta.MotionDirection.RIGHT);
                    break;
                case Clutter.Key.Return:
                case Clutter.Key.KP_Enter:
                    if (!get_active_workspace_clone ().window_container.activate_selected_window ()) {
                        toggle ();
                    }

                    break;
            }

            return false;
        }

        /**
         * Inform the current WindowCloneContainer that we want to move the focus in
         * a specific direction.
         *
         * @param direction The direction in which to move the focus to
         */
        private void select_window (Meta.MotionDirection direction) {
            get_active_workspace_clone ().window_container.select_next_window (direction);
        }

        /**
         * Finds the active WorkspaceClone
         *
         * @return The active WorkspaceClone
         */
        private WorkspaceClone get_active_workspace_clone () {
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            foreach (var child in workspaces.get_children ()) {
                unowned WorkspaceClone workspace_clone = (WorkspaceClone) child;
                if (workspace_clone.workspace == manager.get_active_workspace ()) {
                    return workspace_clone;
                }
            }

            assert_not_reached ();
        }

        private void window_selected (Meta.Window window) {
            var time = display.get_current_time ();
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var workspace = window.get_workspace ();

            if (workspace != manager.get_active_workspace ())
                workspace.activate (time);
            else {
                window.activate (time);
                toggle ();
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
            if (!opened) {
                toggle ();
            }
        }

        /**
         * {@inheritDoc}
         */
        public void close (HashTable<string,Variant>? hints = null) {
            if (opened) {
                toggle ();
            }
        }

        /**
         * Toggles the view open or closed. Takes care of all the wm related tasks, like
         * starting the modal mode and hiding the WindowGroup. Finally tells all components
         * to animate to their positions.
         */
        private void toggle (bool with_gesture = false, bool is_cancel_animation = false) {
            if (animating) {
                return;
            }

            // we don't want to handle cancel animation when animation are off
            if (is_cancel_animation && !wm.enable_animations) {
                return;
            }

            animating = true;

            opened = !opened;
            var opening = opened;

            // https://github.com/elementary/gala/issues/1728
            if (opening) {
                wm.kill_switch_workspace ();
            }

            foreach (var container in window_containers_monitors) {
                if (opening) {
                    container.visible = true;
                    container.open (with_gesture, is_cancel_animation);
                } else {
                    container.close (with_gesture, is_cancel_animation);
                }
            }

            if (opening) {
                modal_proxy = wm.push_modal (this);
                modal_proxy.set_keybinding_filter (keybinding_filter);

                wm.background_group.hide ();
                wm.window_group.hide ();
                wm.top_window_group.hide ();
                show ();
                grab_key_focus ();

                var scale = display.get_monitor_scale (display.get_primary_monitor ());
                icon_groups.force_reposition ();
                icon_groups.y = primary_monitor_container.height - InternalUtils.scale_to_int (WorkspaceClone.BOTTOM_OFFSET - 20, scale);
            } else {
                DragDropAction.cancel_all_by_id ("multitaskingview-window");
            }

            // find active workspace clone and raise it, so there are no overlaps while transitioning
            WorkspaceClone? active_workspace = null;
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var active = manager.get_active_workspace ();
            foreach (var child in workspaces.get_children ()) {
                unowned WorkspaceClone workspace = (WorkspaceClone) child;
                if (workspace.workspace == active) {
                    active_workspace = workspace;
                    break;
                }
            }
            if (active_workspace != null)
                workspaces.set_child_above_sibling (active_workspace, null);

            workspaces.remove_all_transitions ();
            foreach (var child in workspaces.get_children ()) {
                child.remove_all_transitions ();
            }

            if (!is_cancel_animation) {
                update_positions (false);
            }

            foreach (var child in workspaces.get_children ()) {
                unowned WorkspaceClone workspace = (WorkspaceClone) child;
                if (opening) {
                    workspace.open (with_gesture, is_cancel_animation);
                } else {
                    workspace.close (with_gesture, is_cancel_animation);
                }
            }

            if (opening) {
                show_docks (with_gesture, is_cancel_animation);
            } else {
                hide_docks (with_gesture, is_cancel_animation);
            }

            GestureTracker.OnEnd on_animation_end = (percentage, cancel_action) => {
                var animation_duration = cancel_action ? 0 : ANIMATION_DURATION;
                Timeout.add (animation_duration, () => {
                    if (!opening) {
                        foreach (var container in window_containers_monitors) {
                            container.visible = false;
                        }

                        hide ();

                        wm.background_group.show ();
                        wm.window_group.show ();
                        wm.top_window_group.show ();

                        dock_clones.destroy_all_children ();

                        wm.pop_modal (modal_proxy);
                    }

                    animating = false;

                    if (cancel_action) {
                        toggle (false, true);
                    }

                    return false;
                });
            };

            if (!with_gesture) {
                on_animation_end (1, false, 0);
            } else {
                multitasking_gesture_tracker.connect_handlers (null, null, (owned) on_animation_end);
            }
        }

        private void show_docks (bool with_gesture, bool is_cancel_animation) {
            unowned GLib.List<Meta.WindowActor> window_actors = display.get_window_actors ();
            foreach (unowned Meta.WindowActor actor in window_actors) {
                const int MAX_OFFSET = 85;

                if (actor.is_destroyed ())
                    continue;

                unowned Meta.Window window = actor.get_meta_window ();
                var monitor = window.get_monitor ();

                if (window.window_type != Meta.WindowType.DOCK)
                    continue;

                if (display.get_monitor_in_fullscreen (monitor))
                    continue;

                var monitor_geom = display.get_monitor_geometry (monitor);

                var window_geom = window.get_frame_rect ();
                var top = monitor_geom.y + MAX_OFFSET > window_geom.y;
                var bottom = monitor_geom.y + monitor_geom.height - MAX_OFFSET > window_geom.y;

                if (!top && !bottom)
                    continue;

                var initial_x = actor.x;
                var initial_y = actor.y;
                var target_y = (top)
                    ? actor.y - actor.height
                    : actor.y + actor.height;

                var clone = new SafeWindowClone (window, true);
                dock_clones.add_child (clone);

                clone.set_position (initial_x, initial_y);

                GestureTracker.OnUpdate on_animation_update = (percentage) => {
                    var y = GestureTracker.animation_value (initial_y, target_y, percentage);
                    clone.y = y;
                };

                GestureTracker.OnEnd on_animation_end = (percentage, cancel_action) => {
                    if (cancel_action) {
                        return;
                    }

                    clone.save_easing_state ();
                    clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
                    clone.set_easing_duration ((!is_cancel_animation && wm.enable_animations) ? ANIMATION_DURATION : 0);
                    clone.y = target_y;
                    clone.restore_easing_state ();
                };

                if (!with_gesture || !wm.enable_animations) {
                    on_animation_end (1, false, 0);
                } else {
                    multitasking_gesture_tracker.connect_handlers (null, (owned) on_animation_update, (owned) on_animation_end);
                }
            }
        }

        private void hide_docks (bool with_gesture, bool is_cancel_animation) {
            foreach (var child in dock_clones.get_children ()) {
                var dock = (Clutter.Clone) child;
                var initial_y = dock.y;
                var target_y = dock.source.y;

                GestureTracker.OnUpdate on_animation_update = (percentage) => {
                    var y = GestureTracker.animation_value (initial_y, target_y, percentage);
                    dock.y = y;
                };

                GestureTracker.OnEnd on_animation_end = (percentage, cancel_action) => {
                    if (cancel_action) {
                        return;
                    }

                    dock.save_easing_state ();
                    dock.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
                    dock.set_easing_duration (wm.enable_animations ? ANIMATION_DURATION : 0);
                    dock.y = target_y;
                    dock.restore_easing_state ();
                };

                if (!with_gesture || !wm.enable_animations) {
                    on_animation_end (1, false, 0);
                } else {
                    multitasking_gesture_tracker.connect_handlers (null, (owned) on_animation_update, (owned) on_animation_end);
                }
            }
        }

        private bool keybinding_filter (Meta.KeyBinding binding) {
            var action = Meta.Prefs.get_keybinding_action (binding.get_name ());

            // allow super key only when it toggles multitasking view
            if (action == Meta.KeyBindingAction.OVERLAY_KEY &&
                gala_behavior_settings.get_string ("overlay-action") == OPEN_MULTITASKING_VIEW) {
                return false;
            }

            switch (action) {
                case Meta.KeyBindingAction.WORKSPACE_1:
                case Meta.KeyBindingAction.WORKSPACE_2:
                case Meta.KeyBindingAction.WORKSPACE_3:
                case Meta.KeyBindingAction.WORKSPACE_4:
                case Meta.KeyBindingAction.WORKSPACE_5:
                case Meta.KeyBindingAction.WORKSPACE_6:
                case Meta.KeyBindingAction.WORKSPACE_7:
                case Meta.KeyBindingAction.WORKSPACE_8:
                case Meta.KeyBindingAction.WORKSPACE_9:
                case Meta.KeyBindingAction.WORKSPACE_10:
                case Meta.KeyBindingAction.WORKSPACE_11:
                case Meta.KeyBindingAction.WORKSPACE_12:
                case Meta.KeyBindingAction.WORKSPACE_LEFT:
                case Meta.KeyBindingAction.WORKSPACE_RIGHT:
                case Meta.KeyBindingAction.SHOW_DESKTOP:
                case Meta.KeyBindingAction.NONE:
                case Meta.KeyBindingAction.LOCATE_POINTER_KEY:
                    return false;
                default:
                    break;
            }

            switch (binding.get_name ()) {
                case "cycle-workspaces-next":
                case "cycle-workspaces-previous":
                case "switch-to-workspace-first":
                case "switch-to-workspace-last":
                case "zoom-in":
                case "zoom-out":
                case "screenshot":
                case "screenshot-clip":
                    return false;
                default:
                    break;
            }

            return true;
        }
    }
}
