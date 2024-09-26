public class Gala.PropertyGestureTransition : Object {
    public Clutter.Actor actor { get; construct; }
    public GestureTracker gesture_tracker { get; construct; }
    public string property { get; construct; }
    public Value? from_value { get; construct; }
    public Value to_value { get; construct; }
    public bool with_gesture { get; construct; }
    public Value? intermediate_value { get; construct; }

    public PropertyGestureTransition (
        Clutter.Actor actor,
        GestureTracker gesture_tracker,
        string property,
        Value? from_value,
        Value to_value,
        bool with_gesture,
        Value? intermediate_value = null
    ) {
        Object (
            actor: actor,
            gesture_tracker: gesture_tracker,
            property: property,
            from_value: from_value,
            to_value: to_value,
            with_gesture: with_gesture,
            intermediate_value: intermediate_value
        );
    }

    construct {
        ref ();

        if (from_value == null) {
            Value current_value;
            actor.get_property (property, ref current_value);
            from_value = current_value;
        }

        GestureTracker.OnBegin on_animation_begin = () => {
            actor.set_property (property, from_value);
        };

        GestureTracker.OnUpdate on_animation_update = (percentage) => {
            var animation_value = GestureTracker.animation_value (value_to_float (from_value), value_to_float (intermediate_value ?? to_value), percentage);
            actor.set_property (property, value_from_float (animation_value));
        };

        GestureTracker.OnEnd on_animation_end = (percentage, cancel_action, calculated_duration) => {
            if (cancel_action) {
                return;
            }

            actor.save_easing_state ();
            actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
            actor.set_easing_duration (calculated_duration);
            actor.set_property (property, cancel_action ? from_value : to_value);
            actor.restore_easing_state ();

            unref ();
        };

        if (with_gesture) {
            gesture_tracker.connect_handlers (on_animation_begin, on_animation_update, on_animation_end);
        } else {
            on_animation_begin (0);
            on_animation_end (1, false, gesture_tracker.min_animation_duration);
        }
    }

    private float value_to_float (Value val) {
        if (val.holds (typeof (float))) {
            return val.get_float ();
        }

        if (val.holds (typeof (double))) {
            return (float) val.get_double ();
        }

        if (val.holds (typeof (uint))) {
            return (float) val.get_uint ();
        }

        critical ("Non numeric property specified");
        return 0;
    }

    private Value value_from_float (float f) {
        var val = Value (from_value.type ());
        val.set_float (f);
        return val;
    }
}
