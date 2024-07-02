/*
 * Copyright 2020 elementary, Inc (https://elementary.io)
 *           2014 Tom Beckmann
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Gala.NotificationStack : Object {
    public const string TRANSITION_ENTRY_NAME = "entry";
    public const string TRANSITION_MOVE_STACK_ID = "move-stack";

    // we need to keep a small offset to the top, because we clip the container to
    // its allocations and the close button would be off for the first notification
    private const int TOP_OFFSET = 2;
    private const int ADDITIONAL_MARGIN = 12;
    private const int MARGIN = 12;

    private const int WIDTH = 300;

    private int stack_y;
    private int stack_width;

    public Meta.Display display { get; construct; }

    private Gee.ArrayList<unowned Meta.WindowActor> notifications;

    public NotificationStack (Meta.Display display) {
        Object (display: display);
    }

    construct {
        notifications = new Gee.ArrayList<unowned Meta.WindowActor> ();

        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed_internal.connect (update_stack_allocation);
        display.workareas_changed.connect (update_stack_allocation);
        update_stack_allocation ();
    }

    public void show_notification (Meta.WindowActor notification, bool animate)
        requires (notification != null && !notification.is_destroyed () && !notifications.contains (notification)) {

        notification.set_pivot_point (0.5f, 0.5f);

        unowned var window = notification.get_meta_window ();
        if (window == null) {
            warning ("NotificationStack: Unable to show notification, window is null");
            return;
        }

        var window_rect = window.get_frame_rect ();
        window.stick ();

        if (animate) {
            // Don't flicker at the beginning of the animation
            notification.opacity = 0;
            notification.rotation_angle_x = 90;

            var opacity_transition = new Clutter.PropertyTransition ("opacity");
            opacity_transition.set_from_value (0);
            opacity_transition.set_to_value (255);

            var flip_transition = new Clutter.KeyframeTransition ("rotation-angle-x");
            flip_transition.set_from_value (90.0);
            flip_transition.set_to_value (0.0);
            flip_transition.set_key_frames ({ 0.6 });
            flip_transition.set_values ({ -10.0 });

            var entry = new Clutter.TransitionGroup () {
                duration = 400
            };
            entry.add_transition (opacity_transition);
            entry.add_transition (flip_transition);

            notification.transitions_completed.connect (() => notification.remove_all_transitions ());
            notification.add_transition (TRANSITION_ENTRY_NAME, entry);
        }

        var primary = display.get_primary_monitor ();
        var area = display.get_workspace_manager ().get_active_workspace ().get_work_area_for_monitor (primary);
        var scale = display.get_monitor_scale (primary);

        /**
         * We will make space for the incoming notification
         * by shifting all current notifications by height
         * and then add it to the notifications list.
         */
        update_positions (animate, scale, window_rect.height);

        int notification_x_pos = area.x + area.width - window_rect.width;
        if (Clutter.get_default_text_direction () == Clutter.TextDirection.RTL) {
            notification_x_pos = 0;
        }

        move_window (notification, notification_x_pos, stack_y + TOP_OFFSET + InternalUtils.scale_to_int (ADDITIONAL_MARGIN, scale));
        notifications.insert (0, notification);
    }

    private void update_stack_allocation () {
        var primary = display.get_primary_monitor ();
        var area = display.get_workspace_manager ().get_active_workspace ().get_work_area_for_monitor (primary);

        var scale = display.get_monitor_scale (primary);
        stack_width = InternalUtils.scale_to_int (WIDTH + MARGIN, scale);

        stack_y = area.y;
    }

    private void update_positions (bool animate, float scale, float add_y = 0.0f) {
        var y = stack_y + TOP_OFFSET + add_y + InternalUtils.scale_to_int (ADDITIONAL_MARGIN, scale);
        var i = notifications.size;
        var delay_step = i > 0 ? 150 / i : 0;
        var iterator = 0;
        // Need to iterate like this since we might be removing entries
        while (notifications.size > iterator) {
            unowned var actor = notifications.get (iterator);
            iterator++;
            if (actor == null || actor.is_destroyed ()) {
                warning ("NotificationStack: Notification actor was null or destroyed");
                continue;
            }

            if (animate) {
                actor.save_easing_state ();
                actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_BACK);
                actor.set_easing_duration (200);
                actor.set_easing_delay ((i--) * delay_step);
            }

            move_window (actor, -1, (int)y);

            if (animate) {
                actor.restore_easing_state ();
            }

            unowned var window = actor.get_meta_window ();
            if (window == null) {
                // Mutter doesn't let us know when a window is closed if a workspace
                // transition is in progress. I'm not really sure why, but what this
                // means is that we have to remove the notification from the stack
                // manually.
                // See https://github.com/GNOME/mutter/blob/3.36.9/src/compositor/meta-window-actor.c#L882
                notifications.remove (actor);
                warning ("NotificationStack: Notification window was null (probably removed during workspace transition?)");
                continue;
            }

            y += window.get_frame_rect ().height;
        }
    }

    public void destroy_notification (Meta.WindowActor notification, bool animate) {
        if (animate) {
            notification.save_easing_state ();
            notification.set_easing_duration (100);
            notification.set_easing_mode (Clutter.AnimationMode.EASE_IN_QUAD);
            notification.opacity = 0;

            notification.x += stack_width;
            notification.restore_easing_state ();
        } else {
            notification.opacity = 0;
            notification.x += stack_width;
        }

        var primary = display.get_primary_monitor ();
        var scale = display.get_monitor_scale (primary);

        notifications.remove (notification);
        update_positions (animate, scale);
    }

    /**
     * This function takes care of properly updating both the actor
     * position and the actual window position.
     *
     * To enable animations for a window we first need to move it's frame
     * in the compositor and then calculate & apply the coordinates for the window
     * actor.
     */
    private static void move_window (Meta.WindowActor actor, int x, int y) requires (actor != null && !actor.is_destroyed ()) {
        unowned var window = actor.get_meta_window ();
        if (window == null) {
            warning ("NotificationStack: Unable to move the window, window is null");
            return;
        }

        var rect = window.get_frame_rect ();

        window.move_frame (false, x != -1 ? x : rect.x, y != -1 ? y : rect.y);

        /**
         * move_frame does not guarantee that the frame rectangle
         * will be updated instantly, get the buffer rectangle.
         */
        rect = window.get_buffer_rect ();
        actor.set_position (rect.x - ((actor.width - rect.width) / 2), rect.y - ((actor.height - rect.height) / 2));
    }
}
