/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * A class that will animate a property of a {@link Clutter.Actor} one to one with a gesture or
 * with easing without a gesture. Respects the enable animation setting.
 */
public class Gala.GesturePropertyTransition : Object {
    public delegate void DoneCallback ();

    /**
     * The actor whose property will be animated.
     */
    public Clutter.Actor actor { get; construct; }

    public GestureTracker gesture_tracker { get; construct; }

    /**
     * The property that will be animated. To be properly animated it has to be marked as
     * animatable in the Clutter documentation and should be numeric.
     */
    public string property { get; construct; }

    /**
     * The starting value of the animation or null to use the current value. The value
     * has to be of the same type as the property.
     */
    public Value? from_value { get; construct set; }

    /**
     * The value to animate to. It has to be of the same type as the property.
     */
    public Value to_value { get; construct set; }

    /**
     * The lower max overshoot. The gesture percentage by which #this animates the property is bounded
     * by this property on the lower end. If it is in the form X.YY with Y not 0 the animation will be linear
     * until X and then take another 100% to animate until X.YY (instead of YY%).
     * Default is 0.
     */
    public double overshoot_lower_clamp { get; set; default = 0; }
    /**
     * Same as {@link overshoot_lower_clamp} but for the upper limit.
     * If this is less than 1 and the transition is started without a gesture it will animate to
     * the {@link to_value} by this percent and then back to the {@link from_value}.
     * Default is 1.
     */
    public double overshoot_upper_clamp { get; set; default = 1; }

    /**
     * This is the from value that's actually used when calculating the animation movement.
     * If {@link from_value} isn't null this will be the same, otherwise it will be set to the current
     * value of the target property, when calling {@link start}.
     */
    private Value actual_from_value;
    private float from_value_float; // Only valid in the time between start () and finish ()
    private float to_value_float; // Only valid in the time between start () and finish ()

    private DoneCallback? done_callback;

    public GesturePropertyTransition (
        Clutter.Actor actor,
        GestureTracker gesture_tracker,
        string property,
        Value? from_value,
        Value to_value
    ) {
        Object (
            actor: actor,
            gesture_tracker: gesture_tracker,
            property: property,
            from_value: from_value,
            to_value: to_value
        );
    }

    /**
     * Starts animating the property from {@link from_value} to {@link to_value}. If with_gesture is true
     * it will connect to the gesture trackers signals and animate according to the input finishing with an easing
     * to the final position. If with_gesture is false it will just ease to the {@link to_value}.
     * #this will keep itself alive until the animation finishes so it is safe to immediatly unref it after creation and calling start.
     *
     * @param done_callback a callback for when the transition finishes. This shouldn't be used for setting state, instead state should
     * be set immediately on {@link GestureTracker.OnEnd} not only once the animation ends to allow for interrupting the animation by starting a new gesture.
     * done_callback will only be called if the animation finishes, not if it is interrupted e.g. by starting a new animation for the same property,
     * destroying the actor or removing the transition.
     *
     * @return If a transition is currently in progress for the actor and the property the percentage how far the current value
     * is towards the to_value given the final value of the ongoing transition is returned. This is usally the case if a gesture ended but was
     * started again before the animation finished so this should be used to set {@link GestureTracker.initial_percentage}. If no transition
     * is in progress 0 is returned.
     */
    public double start (bool with_gesture, owned DoneCallback? done_callback = null) {
        ref ();

        this.done_callback = (owned) done_callback;

        Value current_value = {};
        actor.get_property (property, ref current_value);

        Value initial_value;

        unowned var old_transition = actor.get_transition (property);
        if (old_transition != null) {
            initial_value = old_transition.interval.final;
        } else {
            initial_value = current_value;
        }

        actual_from_value = from_value ?? initial_value;

        if (actual_from_value.type () != current_value.type ()) {
            warning ("from_value of type %s is not of the same type as the property %s which is %s. Can't animate.", from_value.type_name (), property, current_value.type_name ());
            finish ();
            return 0;
        }

        if (current_value.type () != to_value.type ()) {
            warning ("to_value of type %s is not of the same type as the property %s which is %s. Can't animate.", to_value.type_name (), property, current_value.type_name ());
            finish ();
            return 0;
        }

        // Pre calculate some things, so we don't have to do it on every update
        from_value_float = value_to_float (actual_from_value);
        to_value_float = value_to_float (to_value);

        var current_value_double = (double) value_to_float (current_value);
        var initial_value_double = (double) value_to_float (initial_value);

        var initial_percentage = ((to_value_float - initial_value_double) - (to_value_float - current_value_double)) / (to_value_float - initial_value_double);

        GestureTracker.OnBegin on_animation_begin = (percentage) => {
            var animation_value = GestureTracker.animation_value (from_value_float, to_value_float, percentage, false);
            actor.set_property (property, value_from_float (animation_value));
        };

        GestureTracker.OnUpdate on_animation_update = (percentage) => {
            var lower_clamp_int = (int) overshoot_lower_clamp;
            var upper_clamp_int = (int) overshoot_upper_clamp;

            double stretched_percentage = 0;
            if (percentage < lower_clamp_int) {
                stretched_percentage = (percentage - lower_clamp_int) * - (overshoot_lower_clamp - lower_clamp_int);
            } else if (percentage > upper_clamp_int) {
                stretched_percentage = (percentage - upper_clamp_int) * (overshoot_upper_clamp - upper_clamp_int);
            }

            percentage = percentage.clamp (lower_clamp_int, upper_clamp_int);

            var animation_value = GestureTracker.animation_value (from_value_float, to_value_float, percentage, false);

            if (stretched_percentage != 0) {
                animation_value += (float) stretched_percentage * (to_value_float - from_value_float);
            }

            actor.set_property (property, value_from_float (animation_value));
        };

        GestureTracker.OnEnd on_animation_end = (percentage, completions, calculated_duration) => {
            completions = completions.clamp ((int) overshoot_lower_clamp, (int) overshoot_upper_clamp);
            var target_value = from_value_float + completions * (to_value_float - from_value_float);

            actor.save_easing_state ();
            actor.set_easing_mode (EASE_OUT_QUAD);
            actor.set_easing_duration (AnimationsSettings.get_animation_duration (calculated_duration));
            actor.set_property (property, value_from_float (target_value));
            actor.restore_easing_state ();

            unowned var transition = actor.get_transition (property);
            if (transition == null) {
                finish ();
            } else {
                transition.stopped.connect (finish);
            }
        };

        if (with_gesture && AnimationsSettings.get_enable_animations ()) {
            gesture_tracker.connect_handlers (on_animation_begin, on_animation_update, on_animation_end);
        } else {
            on_animation_begin (0);
            if (overshoot_upper_clamp < 1) {
                actor.save_easing_state ();
                actor.set_easing_mode (EASE_OUT_QUAD);
                actor.set_easing_duration (AnimationsSettings.get_animation_duration (gesture_tracker.min_animation_duration));
                actor.set_property (property, value_from_float ((float) overshoot_upper_clamp * (to_value_float - from_value_float) + from_value_float));
                actor.restore_easing_state ();

                unowned var transition = actor.get_transition (property);
                if (transition == null) {
                    on_animation_end (1, 1, gesture_tracker.min_animation_duration);
                } else {
                    transition.stopped.connect ((is_finished) => {
                        if (is_finished) {
                            on_animation_end (0, 0, gesture_tracker.min_animation_duration);
                        }
                    });
                }
            } else {
                on_animation_end (1, 1, gesture_tracker.min_animation_duration);
            }
        }

        return initial_percentage;
    }

    private void finish (bool callback = true) {
        if (done_callback != null && callback) {
            done_callback ();
        }

        unref ();
    }

    private float value_to_float (Value val) {
        Value float_val = Value (typeof (float));
        if (val.transform (ref float_val)) {
            return float_val.get_float ();
        }

        critical ("Non numeric property specified");
        return 0;
    }

    private Value value_from_float (float f) {
        var float_val = Value (typeof (float));
        float_val.set_float (f);

        var val = Value (actual_from_value.type ());

        if (!float_val.transform (ref val)) {
            warning ("Failed to transform float to give type");
        }

        return val;
    }
}
