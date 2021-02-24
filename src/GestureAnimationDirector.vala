/*
 * Copyright 2020 elementary, Inc (https://elementary.io)
 *           2020 José Expósito <jose.exposito89@gmail.com>
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

public class Gala.GestureAnimationDirector : Object {
    /**
     * Percentage of the animation to be completed to apply the action.
     */
    private const int SUCCESS_PERCENTAGE_THRESHOLD = 20;

    /**
     * When a gesture ends with a velocity greater than this constant, the action is not cancelled,
     * even if the animation threshold has not been reached.
     */
    private const double SUCCESS_VELOCITY_THRESHOLD = 0.3;

    /**
     * When a gesture ends with less velocity that this constant, this velocity is used instead.
     */
    private const double ANIMATION_BASE_VELOCITY = 0.002;

    /**
     * Maximum velocity allowed on gesture update.
     */
    private const double MAX_VELOCITY = 0.5;

    public int min_animation_duration { get; construct; }
    public int max_animation_duration { get; construct; }

    public bool running { get; set; default = false; }
    public bool canceling { get; set; default = false; }

    public signal void on_animation_begin (double percentage);
    public signal void on_animation_update (double percentage);
    public signal void on_animation_end (double percentage, bool cancel_action, int calculated_duration);

    public delegate void OnBegin (double percentage);
    public delegate void OnUpdate (double percentage);
    public delegate void OnEnd (double percentage, bool cancel_action, int calculated_duration);

    private Gee.ArrayList<ulong> handlers;

    private double previous_percentage;
    private uint64 previous_time;
    private double percentage_delta;
    private double velocity;

    construct {
        handlers = new Gee.ArrayList<ulong> ();
        previous_percentage = 0;
        previous_time = 0;
        percentage_delta = 0;
        velocity = 0;
    }

    public GestureAnimationDirector (int min_animation_duration, int max_animation_duration) {
        Object (min_animation_duration: min_animation_duration, max_animation_duration: max_animation_duration);
    }

    public void connect_handlers (owned OnBegin? on_begin, owned OnUpdate? on_update, owned OnEnd? on_end) {
        if (on_begin != null) {
            ulong handler_id = on_animation_begin.connect ((percentage) => on_begin (percentage));
            handlers.add (handler_id);
        }

        if (on_update != null) {
            ulong handler_id = on_animation_update.connect ((percentage) => on_update (percentage));
            handlers.add (handler_id);
        }

        if (on_end != null) {
            ulong handler_id = on_animation_end.connect ((percentage, cancel_action, duration) => on_end (percentage, cancel_action, duration));
            handlers.add (handler_id);
        }
    }

    public void disconnect_all_handlers () {
        foreach (var handler in handlers) {
            disconnect (handler);
        }

        handlers.clear ();
    }

    /**
     * Utility method to calculate the current animation value based on the percentage of the
     * gesture performed.
     * Animations are always linear, as they are 1:1 to the user's movement.
     * @param initial_value Animation start value.
     * @param target_value Animation end value.
     * @param percentage Current animation percentage.
     * @param rounded If the returned value should be rounded to match physical pixels.
     * Default to false because some animations, like for example scaling an actor, use intermediate
     * values not divisible by physical pixels.
     * @returns The linear animation value at the specified percentage.
     */
    public static float animation_value (float initial_value, float target_value, double percentage, bool rounded = false) {
        float value = (((target_value - initial_value) * (float) percentage) / 100) + initial_value;

        if (rounded) {
            var scale_factor = InternalUtils.get_ui_scaling_factor ();
            value = (float) Math.round (value * scale_factor) / scale_factor;
        }

        return value;
    }

    public void update_animation (HashTable<string,Variant> hints) {
        string event = hints.get ("event").get_string ();
        double percentage = hints.get ("percentage").get_double ();
        uint64 elapsed_time = hints.get ("elapsed_time").get_uint64 ();

        switch (event) {
            case "begin":
                update_animation_begin (percentage, elapsed_time);
                break;
            case "update":
                update_animation_update (percentage, elapsed_time);
                break;
            case "end":
            default:
                update_animation_end (percentage, elapsed_time);
                break;
        }
    }

    private void update_animation_begin (double percentage, uint64 elapsed_time) {
        on_animation_begin (percentage);

        previous_percentage = percentage;
        previous_time = elapsed_time;
    }

    private void update_animation_update (double percentage, uint64 elapsed_time) {
        if (elapsed_time != previous_time) {
            double distance = percentage - previous_percentage;
            double time = (double)(elapsed_time - previous_time);
            velocity = (distance / time);

            if (velocity > MAX_VELOCITY) {
                velocity = MAX_VELOCITY;
                var used_percentage = MAX_VELOCITY * time + previous_percentage;
                percentage_delta += percentage - used_percentage;
            }
        }

        on_animation_update (applied_percentage (percentage, percentage_delta));

        previous_percentage = percentage;
        previous_time = elapsed_time;
    }

    private void update_animation_end (double percentage, uint64 elapsed_time) {
        double end_percentage = applied_percentage (percentage, percentage_delta);
        bool cancel_action = (end_percentage < SUCCESS_PERCENTAGE_THRESHOLD)
            && ((end_percentage <= previous_percentage) && (velocity < SUCCESS_VELOCITY_THRESHOLD));
        int calculated_duration = calculate_end_animation_duration (end_percentage, cancel_action);

        on_animation_end (end_percentage, cancel_action, calculated_duration);

        previous_percentage = 0;
        previous_time = 0;
        percentage_delta = 0;
        velocity = 0;
    }

    private static double applied_percentage (double percentage, double percentage_delta) {
        return (percentage - percentage_delta).clamp (0, 100);
    }

    /**
     * Calculates the end animation duration using the current gesture velocity.
     */
     private int calculate_end_animation_duration (double end_percentage, bool cancel_action) {
        double animation_velocity = (velocity > ANIMATION_BASE_VELOCITY)
            ? velocity
            : ANIMATION_BASE_VELOCITY;

        double pending_percentage = cancel_action ? end_percentage : 100 - end_percentage;

        int duration = ((int)(pending_percentage / animation_velocity).abs ())
            .clamp (min_animation_duration, max_animation_duration);
        return duration;
    }
}
