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
    public delegate void DoneCallback (bool cancel_action);

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
     * If not null this can be used to have an intermediate step before animating back to the origin.
     * Therefore using this makes mostly sense if {@link to_value} equals {@link from_value}.
     * This is mostly used for the nudge animations when trying to switch workspaces where there isn't one anymore.
     */
    public Value? intermediate_value { get; construct; }

    /**
     * This is the from value that's actually used when calculating the animation movement.
     * If {@link from_value} isn't null this will be the same, otherwise it will be set to the current
     * value of the target property, when calling {@link start}.
     */
    private Value actual_from_value;

    private DoneCallback? done_callback;

    public GesturePropertyTransition (
        Clutter.Actor actor,
        GestureTracker gesture_tracker,
        string property,
        Value? from_value,
        Value to_value,
        Value? intermediate_value = null
    ) {
        Object (
            actor: actor,
            gesture_tracker: gesture_tracker,
            property: property,
            from_value: from_value,
            to_value: to_value,
            intermediate_value: intermediate_value
        );
    }

    /**
     * Starts animating the property from {@link from_value} to {@link to_value}. If with_gesture is true
     * it will connect to the gesture trackers signals and animate according to the input finishing with an easing
     * to the final position. If with_gesture is false it will just ease to the {@link to_value}.
     * #this will keep itself alive until the animation finishes so it is safe to immediatly unref it after creation and calling start.
     *
     * @param done_callback a callback for when the transition finishes. It is guaranteed to be called exactly once.
     */
    public void start (bool with_gesture, owned DoneCallback? done_callback = null) {
        ref ();

        this.done_callback = (owned) done_callback;

        Value current_value = {};
        actor.get_property (property, ref current_value);

        actual_from_value = from_value ?? current_value;

        if (actual_from_value.type () != current_value.type ()) {
            warning ("from_value of type %s is not of the same type as the property %s which is %s. Can't animate.", from_value.type_name (), property, current_value.type_name ());
            finish (true);
            return;
        }

        if (current_value.type () != to_value.type ()) {
            warning ("to_value of type %s is not of the same type as the property %s which is %s. Can't animate.", to_value.type_name (), property, current_value.type_name ());
            finish (true);
            return;
        }

        GestureTracker.OnBegin on_animation_begin = () => {
            actor.set_property (property, actual_from_value);
        };

        GestureTracker.OnUpdate on_animation_update = (percentage) => {
            var animation_value = GestureTracker.animation_value (value_to_float (actual_from_value), value_to_float (intermediate_value ?? to_value), percentage);
            actor.set_property (property, value_from_float (animation_value));
        };

        GestureTracker.OnEnd on_animation_end = (percentage, cancel_action, calculated_duration) => {
            actor.save_easing_state ();
            actor.set_easing_mode (EASE_OUT_QUAD);
            actor.set_easing_duration (AnimationsSettings.get_animation_duration (calculated_duration));
            actor.set_property (property, cancel_action ? actual_from_value : to_value);
            actor.restore_easing_state ();

            unowned var transition = actor.get_transition (property);
            if (transition == null) {
                finish (cancel_action);
            } else {
                transition.stopped.connect (() => finish (cancel_action));
            }
        };

        if (with_gesture && AnimationsSettings.get_enable_animations ()) {
            gesture_tracker.connect_handlers (on_animation_begin, on_animation_update, on_animation_end);
        } else {
            on_animation_begin (0);
            if (intermediate_value != null) {
                actor.save_easing_state ();
                actor.set_easing_mode (EASE_OUT_QUAD);
                actor.set_easing_duration (AnimationsSettings.get_animation_duration (gesture_tracker.min_animation_duration));
                actor.set_property (property, intermediate_value);
                actor.restore_easing_state ();

                unowned var transition = actor.get_transition (property);
                if (transition == null) {
                    on_animation_end (1, false, gesture_tracker.min_animation_duration);
                } else {
                    transition.stopped.connect (() => on_animation_end (1, false, gesture_tracker.min_animation_duration));
                }
            } else {
                on_animation_end (1, false, gesture_tracker.min_animation_duration);
            }
        }
    }

    private void finish (bool cancel_action) {
        if (done_callback != null) {
            done_callback (cancel_action);
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
