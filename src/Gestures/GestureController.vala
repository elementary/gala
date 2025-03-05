/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * The class responsible for handling gestures and updating the target. It has a persistent
 * double progress that is either updated by a gesture that is configured with the given
 * {@link GestureAction} from various backends (see the enable_* methods) or manually
 * by calling {@link goto} or setting {@link progress} directly.
 * You shouldn't connect a notify to the progress directly though, but rather use a
 * {@link GestureTarget} implementation.
 * The {@link progress} can be seen as representing the state that the UI the gesture affects
 * is currently in (e.g. 0 for multitasking view closed, 1 for it opend, or 0 for first workspace,
 * -1 for second, -2 for third, etc.). Therefore the progress often needs boundaries which can be
 * set with {@link overshoot_lower_clamp} and {@link overshoot_upper_clamp}. If the values are integers
 * it will be a hard boundary, if they are fractional it will slow the gesture progress when over the
 * limit simulating a kind of spring that pushes against it.
 * Note that the progress snaps to full integer values after a gesture ends.
 */
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

    public GestureAction action { get; construct; }

    private GestureTarget? _target;
    public GestureTarget target {
        get { return _target; }
        set {
            _target = value;
            target.propagate (UPDATE, action, calculate_bounded_progress ());
        }
    }

    public double distance { get; construct set; }
    public double overshoot_lower_clamp { get; construct set; default = 0d; }
    public double overshoot_upper_clamp { get; construct set; default = 1d; }

    /**
     * When disabled gesture progress will stay where the gesture ended and not snap to full integers values.
     * This will also cause the controller to emit smooth progress information even if animations are disabled.
     */
    public bool snap { get; construct set; default = true; }

    private double _progress = 0;
    public double progress {
        get { return _progress; }
        set {
            _progress = value;
            target.propagate (UPDATE, action, calculate_bounded_progress ());
        }
    }

    private bool _enabled = true;
    public bool enabled {
        get { return _enabled; }
        set {
            cancel_gesture ();
            _enabled = value;
        }
    }

    public bool recognizing { get; private set; }

    private ToucheggBackend? touchpad_backend;
    private ScrollBackend? scroll_backend;

    private GestureBackend? recognizing_backend;
    private double previous_percentage;
    private uint64 previous_time;
    private double previous_delta;
    private double velocity;
    private int direction_multiplier;

    private Clutter.Timeline? timeline;

    public GestureController (GestureAction action, GestureTarget target) {
        Object (action: action, target: target);
    }

    private double calculate_bounded_progress () {
        var lower_clamp_int = (int) overshoot_lower_clamp;
        var upper_clamp_int = (int) overshoot_upper_clamp;

        double stretched_percentage = 0;
        if (_progress < lower_clamp_int) {
            stretched_percentage = (_progress - lower_clamp_int) * - (overshoot_lower_clamp - lower_clamp_int);
        } else if (_progress > upper_clamp_int) {
            stretched_percentage = (_progress - upper_clamp_int) * (overshoot_upper_clamp - upper_clamp_int);
        }

        var clamped = _progress.clamp (lower_clamp_int, upper_clamp_int);

        return clamped + stretched_percentage;
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

        target.propagate (START, action, calculate_bounded_progress ());
    }

    private bool gesture_detected (GestureBackend backend, Gesture gesture, uint32 timestamp) {
        recognizing = enabled && (GestureSettings.get_action (gesture) == action
            || backend == scroll_backend && GestureSettings.get_action (gesture) == NONE);

        if (recognizing) {
            if (gesture.direction == UP || gesture.direction == RIGHT || gesture.direction == OUT) {
                direction_multiplier = 1;
            } else {
                direction_multiplier = -1;
            }

            if (snap && !AnimationsSettings.get_enable_animations ()) {
                prepare ();
                finish (0, progress + direction_multiplier);
                recognizing = false;
            }

            recognizing_backend = backend;
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

        recognizing = false;

        progress += calculate_applied_delta (percentage, previous_delta);

        var to = progress;

        if (snap) {
            if (velocity.abs () > SUCCESS_VELOCITY_THRESHOLD) {
                to += (velocity > 0 ? direction_multiplier : -direction_multiplier) * 0.5;
            }

            to = Math.round (to);
        }

        finish (velocity, to);

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
        var clamped_to = to.clamp ((int) overshoot_lower_clamp, (int) overshoot_upper_clamp);

        target.propagate (COMMIT, action, clamped_to);

        if (progress == to) {
            target.propagate (END, action, calculate_bounded_progress ());
            return;
        }

        if (!AnimationsSettings.get_enable_animations ()) {
            progress = clamped_to;
            target.propagate (END, action, calculate_bounded_progress ());
            return;
        }

        var spring = new SpringTimeline (target.actor, progress, clamped_to, velocity, 1, 1, 1000);
        spring.progress.connect ((value) => progress = value);
        spring.stopped.connect (() => {
            target.propagate (END, action, calculate_bounded_progress ());
            timeline = null;
        });

        timeline = spring;
    }

    /**
     * Animates to the given progress value.
     * If the gesture is currently recognizing, it will do nothing.
     * If that's not what you want, you should call {@link cancel_gesture} first.
     * If you don't want animation but an immediate jump, you should set {@link progress} directly.
     */
    public void goto (double to) {
        if (progress == to || recognizing) {
            return;
        }

        prepare ();
        finish (0.005, to);
    }

    public void cancel_gesture () {
        if (recognizing) {
            recognizing_backend.cancel_gesture ();
            gesture_end (previous_percentage, previous_time);
        }
    }
}
