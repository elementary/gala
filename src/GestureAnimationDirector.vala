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

    public signal void on_animation_begin (int percentage);
    public signal void on_animation_update (int percentage);
    public signal void on_animation_end (int percentage, bool cancel_action, int calculated_duration);

    public delegate void OnBegin (int percentage);
    public delegate void OnUpdate (int percentage);
    public delegate void OnEnd (int percentage, bool cancel_action, int calculated_duration);

    private Gee.ArrayList<ulong> handlers;

    private int previous_percentage;
    private uint64 previous_time;
    private int percentage_delta;
    private double velocity;

    construct {
        handlers = new Gee.ArrayList<ulong> ();
        previous_percentage = 0;
        previous_time = 0;
        percentage_delta = 0;
        velocity = 0;
    }

    public GestureAnimationDirector(int min_animation_duration, int max_animation_duration) {
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

    public static float animation_value (float initial_value, float target_value, int percentage) {
        return (((target_value - initial_value) * percentage) / 100) + initial_value;
    }

    public void update_animation (HashTable<string,Variant> hints) {
        string event = hints.get ("event").get_string ();
        int32 percentage = hints.get ("percentage").get_int32 ();
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

    private void update_animation_begin (int32 percentage, uint64 elapsed_time) {
        on_animation_begin (percentage);

        previous_percentage = percentage;
        previous_time = elapsed_time;
    }

    private void update_animation_update (int32 percentage, uint64 elapsed_time) {
        if (elapsed_time != previous_time) {
            int distance = percentage - previous_percentage;
            double time = (double)(elapsed_time - previous_time);
            velocity = (distance / time);

            if (velocity > MAX_VELOCITY) {
                velocity = MAX_VELOCITY;
                var used_percentage = MAX_VELOCITY * time + previous_percentage;
                percentage_delta += (int)(percentage - used_percentage);
            }
        }

        on_animation_update (applied_percentage (percentage, percentage_delta));

        previous_percentage = percentage;
        previous_time = elapsed_time;
    }

    private void update_animation_end (int32 percentage, uint64 elapsed_time) {
        int end_percentage = applied_percentage (percentage, percentage_delta);
        bool cancel_action = (end_percentage < SUCCESS_PERCENTAGE_THRESHOLD)
            && ((end_percentage <= previous_percentage) && (velocity < SUCCESS_VELOCITY_THRESHOLD));
        int calculated_duration = calculate_end_animation_duration (end_percentage, cancel_action);

        on_animation_end (end_percentage, cancel_action, calculated_duration);

        previous_percentage = 0;
        previous_time = 0;
        percentage_delta = 0;
        velocity = 0;
    }

    private static int applied_percentage (int percentage, int percentage_delta) {
        return (percentage - percentage_delta).clamp (0, 100);
    }

    /**
     * Calculates the end animation duration using the current gesture velocity.
     */
     private int calculate_end_animation_duration (int end_percentage, bool cancel_action) {
        double animation_velocity = (velocity > ANIMATION_BASE_VELOCITY)
            ? velocity
            : ANIMATION_BASE_VELOCITY;

        int pending_percentage = cancel_action ? end_percentage : 100 - end_percentage;

        int duration = ((int)(pending_percentage / animation_velocity).abs ())
            .clamp (min_animation_duration, max_animation_duration);
        return duration;
    }
}
