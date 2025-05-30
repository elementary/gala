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
    public WindowManager wm { get; construct; }

    private unowned RootTarget? _target;
    public RootTarget target {
        get { return _target; }
        private set {
            _target = value;
            _target.propagate (UPDATE, action, progress);
        }
    }

    private Variant? _action_info;
    public Variant? action_info { get { return _action_info; } }

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
            target.propagate (UPDATE, action, value);
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
    private double gesture_progress;
    private double previous_percentage;
    private uint64 previous_time;
    private double previous_delta;
    private double velocity;
    private int direction_multiplier;

    private SpringTimeline? timeline;

    public GestureController (GestureAction action, WindowManager wm) {
        Object (action: action, wm: wm);
    }

    /**
     * Do not call this directly, use {@link RooTarget.add_controller} instead.
     */
    public void attached (RootTarget target) {
        ref ();
        this.target = target;
    }

    public void detached () {
        _target = null;
        unref ();
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
            timeline = null;
        } else {
            target.propagate (START, action, progress);
        }
    }

    private bool gesture_detected (GestureBackend backend, Gesture gesture, uint32 timestamp) {
        if (recognizing || !enabled) {
            return false;
        }

        var recognized_action = GestureSettings.get_action (gesture, out _action_info);
        recognizing = !wm.filter_action (recognized_action) && recognized_action == action ||
            backend == scroll_backend && recognized_action == NONE;

        if (recognizing) {
            if (gesture.direction == UP || gesture.direction == RIGHT || gesture.direction == OUT) {
                direction_multiplier = 1;
            } else {
                direction_multiplier = -1;
            }

            if (snap && !Meta.Prefs.get_gnome_animations ()) {
                recognizing = false;
                prepare ();
                finish (0, progress + direction_multiplier);
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

        gesture_progress = progress;
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

        update_gesture_progress (percentage, updated_delta);

        previous_percentage = percentage;
        previous_time = elapsed_time;
        previous_delta = updated_delta;
    }

    private void gesture_end (double percentage, uint64 elapsed_time) {
        if (!recognizing) {
            return;
        }

        recognizing = false;

        update_gesture_progress (percentage, previous_delta);

        var to = progress;

        if (snap) {
            if (velocity.abs () > SUCCESS_VELOCITY_THRESHOLD) {
                to += (velocity > 0 ? direction_multiplier : -direction_multiplier) * 0.5;
            }

            to = Math.round (to);
        }

        finish (velocity * direction_multiplier, to);

        gesture_progress = 0;
        previous_percentage = 0;
        previous_time = 0;
        previous_delta = 0;
        velocity = 0;
        direction_multiplier = 0;
    }

    private void update_gesture_progress (double percentage, double percentage_delta) {
        gesture_progress += ((percentage - percentage_delta) - (previous_percentage - previous_delta)) * direction_multiplier;

        var lower_clamp_int = (int) overshoot_lower_clamp;
        var upper_clamp_int = (int) overshoot_upper_clamp;

        double stretched_percentage = 0;
        if (gesture_progress < lower_clamp_int) {
            stretched_percentage = (gesture_progress - lower_clamp_int) * - (overshoot_lower_clamp - lower_clamp_int);
        } else if (gesture_progress > upper_clamp_int) {
            stretched_percentage = (gesture_progress - upper_clamp_int) * (overshoot_upper_clamp - upper_clamp_int);
        }

        var clamped = gesture_progress.clamp (lower_clamp_int, upper_clamp_int);

        progress = clamped + stretched_percentage;
    }

    private void finish (double velocity, double to) {
        var clamped_to = to.clamp ((int) overshoot_lower_clamp, (int) overshoot_upper_clamp);

        target.propagate (COMMIT, action, clamped_to);

        if (progress == to) {
            finished ();
            return;
        }

        if (!Meta.Prefs.get_gnome_animations ()) {
            progress = clamped_to;
            finished ();
            return;
        }

        var spring = new SpringTimeline (target.actor, progress, clamped_to, velocity, 1, 1, 500);
        spring.progress.connect ((value) => progress = value);
        spring.stopped.connect_after (finished);

        timeline = spring;
    }

    private void finished (bool is_finished = true) requires (is_finished) {
        target.propagate (END, action, progress);
        timeline = null;
        _action_info = null;
    }

    /**
     * Animates to the given progress value.
     * If the gesture is currently recognizing, it will do nothing.
     * If that's not what you want, you should call {@link cancel_gesture} first.
     * If you don't want animation but an immediate jump, you should set {@link progress} directly.
     */
    public void goto (double to) {
        var clamped_to = to.clamp ((int) overshoot_lower_clamp, (int) overshoot_upper_clamp);
        if (progress == to || recognizing ||
            timeline != null && clamped_to == timeline.value_to // Only allow overshoot if there's no ongoing overshoot animation to prevent stacking
        ) {
            return;
        }

        prepare ();
        finish ((to > progress ? 1 : -1) * 1, to);
    }

    public void cancel_gesture () {
        if (recognizing) {
            recognizing_backend.cancel_gesture ();
            gesture_end (previous_percentage, previous_time);
        }
    }
}
