/*
 * Copyright 2021 elementary, Inc (https://elementary.io)
 *           2021 José Expósito <jose.exposito89@gmail.com>
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

public interface Gala.GestureBackend : Object {
    public signal bool on_gesture_detected (Gesture gesture, uint32 timestamp);
    public signal void on_begin (double delta, uint64 time);
    public signal void on_update (double delta, uint64 time);
    public signal void on_end (double delta, uint64 time);

    public virtual void prepare_gesture_handling () { }
}

/**
 * Allow to use multi-touch gestures from different sources (backends).
 * Usage:
 *
 *  * Create a new instance of the class
 *  * Use the enable_* methods to enable different backends\
 *  * Connect the on_gesture_detected to your code
 *  * When on_gesture_detected is emitted, if you want to handle the gesture, call connect_handlers to start receiving events
 *  * on_begin will be emitted once right after on_gesture_detected
 *  * on_update will be emitted 0 or more times
 *  * on_end will be emitted once when the gesture end
 *  * When on_end is emitted, the handler connected with connect_handlers will be automatically disconnected and you will only receive on_gesture_detected signals
 *  * The enabled flag is usually disabled on_end and re-enabled once the end animation finish. In this way, new gestures are not received while animating
 */
public class Gala.GestureTracker : Object {
    /**
     * Percentage of the animation to be completed to apply the action.
     */
    private const double SUCCESS_PERCENTAGE_THRESHOLD = 0.2;

    /**
     * When a gesture ends with a velocity greater than this constant, the action is not cancelled,
     * even if the animation threshold has not been reached.
     */
    private const double SUCCESS_VELOCITY_THRESHOLD = 0.003;

    /**
     * When a gesture ends with less velocity that this constant, this velocity is used instead.
     */
    private const double ANIMATION_BASE_VELOCITY = 0.002;

    /**
     * Maximum velocity allowed on gesture update.
     */
    private const double MAX_VELOCITY = 0.01;

    /**
     * Multiplier used to match libhandy's animation duration.
     */
    private const int DURATION_MULTIPLIER = 3;

    public GestureSettings settings { get; construct; }
    public int min_animation_duration { get; construct; }
    public int max_animation_duration { get; construct; }

    /**
     * Property to control when event signals are emitted or not.
     */
    public bool enabled { get; set; default = true; }

    public bool recognizing { get; private set; }

    /**
     * Emitted when a new gesture is detected.
     * This should only be used to determine whether the gesture should be handled. This shouldn't
     * do any preparations instead those should be done in {@link on_gesture_handled}. This is because
     * the backend might have to do some preparations itself before you are allowed to do some to avoid
     * conflicts.
     * @param gesture Information about the gesture.
     * @return true if the gesture will be handled false otherwise. If false is returned the other
     * signals may still be emitted but aren't guaranteed to be.
     */
    public signal bool on_gesture_detected (Gesture gesture);

    /**
     * Emitted if true was returned form {@link on_gesture_detected}. This should
     * be used to do any preparations for gesture handling and to call {@link connect_handlers} to
     * start receiving updates.
     * @param gesture the same gesture as in {@link on_gesture_detected}
     * @param timestamp the timestamp of the event that initiated the gesture or {@link Meta.CURRENT_TIME}.
     * @return the initial percentage that should already be preapplied. This is useful
     * if an animation was still ongoing when the gesture was started.
     */
    public signal double on_gesture_handled (Gesture gesture, uint32 timestamp);

    /**
     * Emitted right after on_gesture_detected with the initial gesture information.
     * @param percentage Value between 0 and 1.
     */
    public signal void on_begin (double percentage);

    /**
     * Called every time the percentage changes.
     * @param percentage Value between 0 and 1.
     */
    public signal void on_update (double percentage);

    /**
     * @param percentage Value between 0 and 1.
     * @param completions The number of times a full cycle of the gesture was completed in this go. Can be
     * negative if the gesture was started in one direction but ended in the other. This is used to update
     * the UI to the according state. 0 for example means that the UI should go back to the same state
     * it was in before the gesture started.
     */
    public signal void on_end (double percentage, int completions, int calculated_duration);

    public delegate void OnBegin (double percentage);
    public delegate void OnUpdate (double percentage);
    public delegate void OnEnd (double percentage, int completions, int calculated_duration);

    /**
     * Backend used if enable_touchpad is called.
     */
    private ToucheggBackend touchpad_backend;

    /**
     * Scroll backend used if enable_scroll is called.
     */
    private ScrollBackend scroll_backend;

    private Gee.ArrayList<ulong> handlers;

    private double applied_percentage;
    private double previous_percentage;
    private uint64 previous_time;
    private double previous_delta;
    private double velocity;
    // Used to check whether to cancel. Necessary because on_end is often called
    // with the same percentage as the last update so this is the one before the last update.
    private double old_previous;

    construct {
        settings = new GestureSettings ();

        handlers = new Gee.ArrayList<ulong> ();
        applied_percentage = 0;
        previous_percentage = 0;
        previous_time = 0;
        previous_delta = 0;
        velocity = 0;
        old_previous = 0;
    }

    public GestureTracker (int min_animation_duration, int max_animation_duration) {
        Object (min_animation_duration: min_animation_duration, max_animation_duration: max_animation_duration);
    }

    /**
     * Allow to receive touchpad multi-touch gestures.
     */
    public void enable_touchpad () {
        touchpad_backend = ToucheggBackend.get_default ();
        touchpad_backend.on_gesture_detected.connect (gesture_detected);
        touchpad_backend.on_begin.connect (gesture_begin);
        touchpad_backend.on_update.connect (gesture_update);
        touchpad_backend.on_end.connect (gesture_end);
    }

    /**
     * Allow to receive scroll gestures.
     * @param actor Clutter actor that will receive the scroll events.
     * @param orientation If we are interested in the horizontal or vertical axis.
     */
    public void enable_scroll (Clutter.Actor actor, Clutter.Orientation orientation) {
        scroll_backend = new ScrollBackend (actor, orientation, settings);
        scroll_backend.on_gesture_detected.connect (gesture_detected);
        scroll_backend.on_begin.connect (gesture_begin);
        scroll_backend.on_update.connect (gesture_update);
        scroll_backend.on_end.connect (gesture_end);
    }

    public void connect_handlers (owned OnBegin? on_begin_handler, owned OnUpdate? on_update_handler, owned OnEnd? on_end_handler) {
        if (on_begin_handler != null) {
            ulong handler_id = on_begin.connect ((percentage) => on_begin_handler (percentage));
            handlers.add (handler_id);
        }

        if (on_update_handler != null) {
            ulong handler_id = on_update.connect ((percentage) => on_update_handler (percentage));
            handlers.add (handler_id);
        }

        if (on_end_handler != null) {
            ulong handler_id = on_end.connect ((percentage, cancel_action, duration) => on_end_handler (percentage, cancel_action, duration));
            handlers.add (handler_id);
        }
    }

    /**
     * Connects a callback that will only be called if != 0 completions were made.
     * If with_gesture is false it will be called immediately, otherwise once {@link on_end} is emitted.
     */
    public void add_success_callback (bool with_gesture, owned OnEnd callback) {
        if (!with_gesture) {
            callback (1, 1, min_animation_duration);
        } else {
            ulong handler_id = on_end.connect ((percentage, completions, duration) => {
                if (completions != 0) {
                    callback (percentage, completions, duration);
                }
            });
            handlers.add (handler_id);
        }
    }

    private void disconnect_all_handlers () {
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
     * @return The linear animation value at the specified percentage.
     */
    public static float animation_value (float initial_value, float target_value, double percentage, bool rounded = false) {
        float value = initial_value;

        if (initial_value != target_value) {
            value = ((target_value - initial_value) * (float) percentage) + initial_value;
        }

        if (rounded) {
            value = Math.roundf (value);
        }

        return value;
    }

    private bool gesture_detected (GestureBackend backend, Gesture gesture, uint32 timestamp) {
        if (enabled && on_gesture_detected (gesture)) {
            backend.prepare_gesture_handling ();
            applied_percentage = on_gesture_handled (gesture, timestamp);
            return true;
        }

        return false;
    }

    private void gesture_begin (double percentage, uint64 elapsed_time) {
        if (enabled) {
            on_begin (applied_percentage);
        }

        recognizing = true;
        previous_percentage = percentage;
        previous_time = elapsed_time;
    }

    private void gesture_update (double percentage, uint64 elapsed_time) {
        var updated_delta = previous_delta;
        if (elapsed_time != previous_time) {
            double distance = percentage - previous_percentage;
            double time = (double)(elapsed_time - previous_time);
            velocity = (distance / time);

            if (velocity > MAX_VELOCITY) {
                velocity = MAX_VELOCITY;
                var used_percentage = MAX_VELOCITY * time + previous_percentage;
                updated_delta += percentage - used_percentage;
            }
        }

        applied_percentage += calculate_applied_delta (percentage, updated_delta);

        if (enabled) {
            on_update (applied_percentage);
        }

        old_previous = previous_percentage;
        previous_percentage = percentage;
        previous_time = elapsed_time;
        previous_delta = updated_delta;
    }

    private void gesture_end (double percentage, uint64 elapsed_time) {
        applied_percentage += calculate_applied_delta (percentage, previous_delta);

        int completions = (int) applied_percentage;

        var remaining_percentage = applied_percentage - completions;

        bool cancel_action = ((percentage - completions).abs () < SUCCESS_PERCENTAGE_THRESHOLD) && (velocity.abs () < SUCCESS_VELOCITY_THRESHOLD)
            || ((percentage.abs () < old_previous.abs ()) && (velocity.abs () > SUCCESS_VELOCITY_THRESHOLD));

        int calculated_duration = calculate_end_animation_duration (remaining_percentage, cancel_action);

        if (!cancel_action) {
            completions += applied_percentage < 0 ? -1 : 1;
        }

        if (enabled) {
            on_end (applied_percentage, completions, calculated_duration);
        }

        disconnect_all_handlers ();
        recognizing = false;
        applied_percentage = 0;
        previous_percentage = 0;
        previous_time = 0;
        previous_delta = 0;
        velocity = 0;
        old_previous = 0;
    }

    /**
     * Calculate the delta between the new percentage and the previous one while taking into account
     * the velocity delta which makes sure we don't go over the MAX_VELOCITY. The velocity delta we use
     * for the calculation shouldn't be confused with this delta.
     */
    private inline double calculate_applied_delta (double percentage, double percentage_delta) {
        return (percentage - percentage_delta) - (previous_percentage - previous_delta);
    }

    /**
     * Calculates the end animation duration using the current gesture velocity.
     */
    private int calculate_end_animation_duration (double end_percentage, bool cancel_action) {
        double animation_velocity = (velocity > ANIMATION_BASE_VELOCITY)
            ? velocity
            : ANIMATION_BASE_VELOCITY;

        double pending_percentage = cancel_action ? end_percentage : 1 - end_percentage;

        int duration = ((int)(pending_percentage / animation_velocity).abs () * DURATION_MULTIPLIER)
            .clamp (min_animation_duration, max_animation_duration);
        return duration;
    }
 }
