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

        public WindowManagerGala wm { get; construct; }

        private Meta.Display display;
        private ModalProxy modal_proxy;
        private bool opened = false;
        private bool animating = false;

        private List<MonitorClone> window_containers_monitors;

        private IconGroupContainer icon_groups;
        private Clutter.Actor workspaces;
        private Clutter.Actor primary_monitor_container;
        private Clutter.BrightnessContrastEffect brightness_effect;

        private GLib.Settings gala_behavior_settings;
        private Drawing.StyleManager style_manager;

        private bool switching_workspace_with_gesture = false;

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

            multitasking_gesture_tracker = new GestureTracker (ANIMATION_DURATION, ANIMATION_DURATION);
            multitasking_gesture_tracker.enable_touchpad ();
            multitasking_gesture_tracker.on_gesture_detected.connect (on_multitasking_gesture_detected);
            multitasking_gesture_tracker.on_gesture_handled.connect (on_multitasking_gesture_handled);

            workspace_gesture_tracker = new GestureTracker (AnimationDuration.WORKSPACE_SWITCH_MIN, AnimationDuration.WORKSPACE_SWITCH);
            workspace_gesture_tracker.enable_touchpad ();
            workspace_gesture_tracker.enable_scroll (this, Clutter.Orientation.HORIZONTAL);
            workspace_gesture_tracker.on_gesture_detected.connect (on_workspace_gesture_detected);
            workspace_gesture_tracker.on_gesture_handled.connect (switch_workspace_with_gesture);

            workspaces = new Clutter.Actor ();

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
            primary_monitor_container = new Clutter.Actor ();
            primary_monitor_container.add_child (icon_groups);
            primary_monitor_container.add_child (workspaces);
            add_child (primary_monitor_container);

            unowned var manager = display.get_workspace_manager ();
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

                    var monitor_clone = new MonitorClone (display, monitor, multitasking_gesture_tracker);
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
         * GestureTracker.
         */
#if HAS_MUTTER45
        public override bool scroll_event (Clutter.Event scroll_event) {
#else
        public override bool scroll_event (Clutter.ScrollEvent scroll_event) {
#endif
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

            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var active_workspace = manager.get_active_workspace ();
            var new_workspace = active_workspace.get_neighbor (direction);

            if (active_workspace != new_workspace) {
                new_workspace.activate (scroll_event.get_time ());
            } else {
                play_nudge_animation (direction);
            }

            return true;
        }

        public void play_nudge_animation (Meta.MotionDirection direction) {
            if (!AnimationsSettings.get_enable_animations ()) {
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

        private bool on_multitasking_gesture_detected (Gesture gesture) {
            if (GestureSettings.get_action (gesture) != MULTITASKING_VIEW) {
                return false;
            }

            if (gesture.direction == UP && !opened || gesture.direction == DOWN && opened) {
                return true;
            }

            return false;
        }

        private double on_multitasking_gesture_handled (Gesture gesture, uint32 timestamp) {
            toggle (true, false);
            return 0;
        }

        private bool on_workspace_gesture_detected (Gesture gesture) {
            if (!opened) {
                return false;
            }

            if (gesture.type == SCROLL || GestureSettings.get_action (gesture) == SWITCH_WORKSPACE) {
                return true;
            }

            return false;
        }

        private double switch_workspace_with_gesture (Gesture gesture, uint32 timestamp) {
            var direction = workspace_gesture_tracker.settings.get_natural_scroll_direction (gesture);

            unowned var manager = display.get_workspace_manager ();
            var num_workspaces = manager.get_n_workspaces ();
            var relative_dir = (direction == Meta.MotionDirection.LEFT) ? -1 : 1;

            unowned var active_workspace = manager.get_active_workspace ();

            var target_workspace_index = active_workspace.index () + relative_dir;
            var target_workspace_exists = target_workspace_index >= 0 && target_workspace_index < num_workspaces;
            unowned var target_workspace = manager.get_workspace_by_index (target_workspace_index);

            float initial_x = workspaces.x;
            float target_x = 0;
            bool is_nudge_animation = !target_workspace_exists;

            if (is_nudge_animation) {
                var workspaces_geometry = InternalUtils.get_workspaces_geometry (display);
                target_x = initial_x + (workspaces_geometry.width * -relative_dir);
            } else {
                foreach (unowned var child in workspaces.get_children ()) {
                    unowned var workspace_clone = (WorkspaceClone) child;
                    var workspace = workspace_clone.workspace;

                    if (workspace == target_workspace) {
                        target_x = -workspace_clone.multitasking_view_x ();
                    }
                }
            }

            debug ("Starting MultitaskingView switch workspace animation:");
            debug ("Active workspace index: %d", active_workspace.index ());
            debug ("Target workspace index: %d", target_workspace_index);
            debug ("Total number of workspaces: %d", num_workspaces);
            debug ("Is nudge animation: %s", is_nudge_animation ? "Yes" : "No");
            debug ("Initial X: %f", initial_x);
            debug ("Target X: %f", target_x);

            switching_workspace_with_gesture = true;

            var upper_clamp = (direction == LEFT) ? (active_workspace.index () + 0.1) : (num_workspaces - active_workspace.index () - 0.9);
            var lower_clamp = (direction == RIGHT) ? - (active_workspace.index () + 0.1) : - (num_workspaces - active_workspace.index () - 0.9);

            var initial_percentage = new GesturePropertyTransition (workspaces, workspace_gesture_tracker, "x", null, target_x) {
                overshoot_lower_clamp = lower_clamp,
                overshoot_upper_clamp = upper_clamp
            }.start (true);

            GestureTracker.OnEnd on_animation_end = (percentage, completions, calculated_duration) => {
                switching_workspace_with_gesture = false;

                completions = completions.clamp ((int) lower_clamp, (int) upper_clamp);
                manager.get_workspace_by_index (active_workspace.index () + completions * relative_dir).activate (display.get_current_time ());
            };

            if (!AnimationsSettings.get_enable_animations ()) {
                on_animation_end (1, 1, 0);
            } else {
                workspace_gesture_tracker.connect_handlers (null, null, (owned) on_animation_end);
            }

            return initial_percentage;
        }

        /**
         * Places the WorkspaceClones, moves the view so that the active one is shown
         * and does the same for the IconGroups.
         *
         * @param animate Whether to animate the movement or have all elements take their
         *                positions immediately.
         */
        private void update_positions (bool animate) {
            if (switching_workspace_with_gesture) {
                return;
            }

            unowned var manager = display.get_workspace_manager ();
            var active_workspace = manager.get_active_workspace ();
            var active_x = 0.0f;

            foreach (unowned var child in workspaces.get_children ()) {
                unowned var workspace_clone = (WorkspaceClone) child;
                var workspace = workspace_clone.workspace;
                var dest_x = workspace_clone.multitasking_view_x ();

                if (workspace == active_workspace) {
                    active_x = dest_x;
                }

                workspace_clone.save_easing_state ();
                workspace_clone.set_easing_duration ((animate && AnimationsSettings.get_enable_animations ()) ? 200 : 0);
                workspace_clone.x = dest_x;
                workspace_clone.restore_easing_state ();
            }

            workspaces.save_easing_state ();
            workspaces.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            workspaces.set_easing_duration ((animate && AnimationsSettings.get_enable_animations ()) ? AnimationDuration.WORKSPACE_SWITCH_MIN : 0);
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

            if (animate) {
                icon_groups.restore_easing_state ();
            }
        }

        private void add_workspace (int num) {
            unowned var manager = display.get_workspace_manager ();
            var scale = display.get_monitor_scale (display.get_primary_monitor ());

            var workspace = new WorkspaceClone (manager.get_workspace_by_index (num), multitasking_gesture_tracker, scale);
            workspaces.insert_child_at_index (workspace, num);
            icon_groups.add_group (workspace.icon_group);

            workspace.window_selected.connect (window_selected);
            workspace.selected.connect (activate_workspace);

            update_positions (false);

            if (opened) {
                workspace.open ();
            }
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

            if (close_view) {
                toggle ();
            }
        }

        /**
         * Collect key events, mainly for redirecting them to the WindowCloneContainers to
         * select the active window.
         */
#if HAS_MUTTER45
        public override bool key_press_event (Clutter.Event event) {
#else
        public override bool key_press_event (Clutter.KeyEvent event) {
#endif
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
            if (is_cancel_animation && !AnimationsSettings.get_enable_animations ()) {
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
            foreach (unowned var child in workspaces.get_children ()) {
                unowned WorkspaceClone workspace = (WorkspaceClone) child;
                if (workspace.workspace == active) {
                    active_workspace = workspace;
                    break;
                }
            }
            if (active_workspace != null) {
                workspaces.set_child_above_sibling (active_workspace, null);
            }

            workspaces.remove_all_transitions ();
            foreach (unowned var child in workspaces.get_children ()) {
                child.remove_all_transitions ();
            }

            if (!is_cancel_animation) {
                update_positions (false);
            }

            foreach (unowned var child in workspaces.get_children ()) {
                unowned WorkspaceClone workspace = (WorkspaceClone) child;
                if (opening) {
                    workspace.open (with_gesture, is_cancel_animation);
                } else {
                    workspace.close (with_gesture, is_cancel_animation);
                }
            }

            if (opening) {
                ShellClientsManager.get_instance ().add_state (MULTITASKING_VIEW, multitasking_gesture_tracker, with_gesture);
            } else {
                ShellClientsManager.get_instance ().remove_state (MULTITASKING_VIEW, multitasking_gesture_tracker, with_gesture);
            }

            GestureTracker.OnEnd on_animation_end = (percentage, completions) => {
                var animation_duration = completions == 0 ? 0 : ANIMATION_DURATION;
                Timeout.add (animation_duration, () => {
                    if (!opening) {
                        foreach (var container in window_containers_monitors) {
                            container.visible = false;
                        }

                        hide ();

                        wm.background_group.show ();
                        wm.window_group.show ();
                        wm.top_window_group.show ();

                        wm.pop_modal (modal_proxy);
                    }

                    animating = false;

                    if (completions == 0) {
                        toggle (false, true);
                    }

                    return Source.REMOVE;
                });
            };

            if (!with_gesture) {
                on_animation_end (1, 1, 0);
            } else {
                multitasking_gesture_tracker.connect_handlers (null, null, (owned) on_animation_end);
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
