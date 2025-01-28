/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Gala.GestureTarget : Object {
    /**
     * The actor manipulated by the gesture. The associated frame clock
     * will be used for animation timelines.
     */
    public abstract Clutter.Actor? actor { get; }

    // Add a string id to every call and only do stuff if the id matches
    public virtual void start (string id) {}
    public virtual void update (string id, double progress) {}
    public virtual void commit (string id, double to) {}
    public virtual void end (string id) {}
}

public class Gala.GestureController : Object {
    /**
     * When a gesture ends with a velocity greater than this constant, the action is not cancelled,
     * even if the animation threshold has not been reached.
     */
    private const double SUCCESS_VELOCITY_THRESHOLD = 0.003;

    /**
     * Maximum velocity allowed on gesture update.
     */
    private const double MAX_VELOCITY = 0.01;

    public GestureSettings.GestureAction action { get; construct set; }
    public double distance { get; construct set; }
    public double overshoot_lower_clamp { get; construct set; default = 0d; }
    public double overshoot_upper_clamp { get; construct set; default = 1d; }

    private double _progress = 0;
    public double progress {
        get { return _progress; }
        set {
            _progress = value;

            var lower_clamp_int = (int) overshoot_lower_clamp;
            var upper_clamp_int = (int) overshoot_upper_clamp;

            double stretched_percentage = 0;
            if (progress < lower_clamp_int) {
                stretched_percentage = (progress - lower_clamp_int) * - (overshoot_lower_clamp - lower_clamp_int);
            } else if (progress > upper_clamp_int) {
                stretched_percentage = (progress - upper_clamp_int) * (overshoot_upper_clamp - upper_clamp_int);
            }

            var clamped = progress.clamp (lower_clamp_int, upper_clamp_int);

            target.update (id, clamped + stretched_percentage);
        }
    }

    public GestureTarget target { get; construct set; }

    public string id { get; construct; }

    private ToucheggBackend touchpad_backend;
    private ScrollBackend scroll_backend;

    private bool recognizing = false;
    private double previous_percentage;
    private uint64 previous_time;
    private double previous_delta;
    private double velocity;
    private int direction_multiplier;

    private Clutter.Timeline? timeline;

    public GestureController (GestureSettings.GestureAction action, string id) {
        Object (action: action, id: id);
    }

    public void enable_touchpad () {
        touchpad_backend = ToucheggBackend.get_default ();
        touchpad_backend.on_gesture_detected.connect (gesture_detected);
        touchpad_backend.on_begin.connect (gesture_begin);
        touchpad_backend.on_update.connect (gesture_update);
        touchpad_backend.on_end.connect (gesture_end);
    }

    public void enable_scroll (Clutter.Actor actor, Clutter.Orientation orientation) {
        scroll_backend = new ScrollBackend (actor, orientation, new GestureSettings ());
        scroll_backend.on_gesture_detected.connect (gesture_detected);
        scroll_backend.on_begin.connect (gesture_begin);
        scroll_backend.on_update.connect (gesture_update);
        scroll_backend.on_end.connect (gesture_end);
    }

    private void prepare () {
        if (timeline != null) {
            timeline.stop ();
            timeline = null;
        }

        target.start (id);
    }

    private bool gesture_detected (GestureBackend backend, Gesture gesture, uint32 timestamp) {
        recognizing = GestureSettings.get_action (gesture) == action || GestureSettings.get_action (gesture) == NONE;

        if (recognizing) {
            if (gesture.direction == UP || gesture.direction == RIGHT) {
                direction_multiplier = 1;
            } else {
                direction_multiplier = -1;
            }
        }

        return recognizing;
    }

    private void gesture_begin (double percentage, uint64 elapsed_time) {
        if (!recognizing) {
            return;
        }

        prepare ();

        previous_percentage = percentage;
        previous_time = elapsed_time;
    }

    private void gesture_update (double percentage, uint64 elapsed_time) {
        if (!recognizing) {
            return;
        }

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

        progress += calculate_applied_delta (percentage, updated_delta);

        previous_percentage = percentage;
        previous_time = elapsed_time;
        previous_delta = updated_delta;
    }

    private void gesture_end (double percentage, uint64 elapsed_time) {
        if (!recognizing) {
            return;
        }

        progress += calculate_applied_delta (percentage, previous_delta);

        int completions = (int) Math.round (progress);

        if (velocity.abs () > SUCCESS_VELOCITY_THRESHOLD) {
            completions += velocity > 0 ? direction_multiplier : -direction_multiplier;
        }

        var lower_clamp_int = (int) overshoot_lower_clamp;
        var upper_clamp_int = (int) overshoot_upper_clamp;

        completions = completions.clamp (lower_clamp_int, upper_clamp_int);

        recognizing = false;

        finish (velocity, (double) completions);

        previous_percentage = 0;
        previous_time = 0;
        previous_delta = 0;
        velocity = 0;
        direction_multiplier = 0;
    }

    private inline double calculate_applied_delta (double percentage, double percentage_delta) {
        return ((percentage - percentage_delta) - (previous_percentage - previous_delta)) * direction_multiplier;
    }

    private void finish (double velocity, double to) {
        var transition = new SpringTimeline (target.actor, progress, to, velocity, 1, 0.5, 500);
        transition.progress.connect ((value) => progress = value);
        transition.stopped.connect (() => {
            target.end (id);
            timeline = null;
        });

        timeline = transition;

        target.commit (id, to);
    }

    public void goto (double to) {
        if (progress == to) {
            return;
        }

        prepare ();
        finish (0.005, to);
    }
}
