/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.PropertyAnimator : Object {
    public struct AnimatableProperty {
        string property;
        Type value_type;
        Value? from_value;
        Value target_value;
    }

    public delegate void OnStopped (Clutter.Actor actor);

    private Clutter.Actor actor;
    private OnStopped on_stopped;

    public PropertyAnimator (
        Clutter.Actor actor,
        uint duration,
        Clutter.AnimationMode animation_mode,
        AnimatableProperty[] properties,
        OnStopped on_stopped
    ) {
        this.actor = actor;
        this.on_stopped = on_stopped;

        ref ();

        if (!Meta.Prefs.get_gnome_animations ()) {
            call_on_stopped ();
            return;
        }

        for (var i = 0; i < properties.length; i++) {
            var property = properties[i];

            Value actor_current_property = {};
            actor.get_property (property.property, ref actor_current_property);

            var transition = new Clutter.PropertyTransition (property.property) {
                progress_mode = animation_mode,
                remove_on_complete = true,
                duration = duration,
                interval = new Clutter.Interval.with_values (
                    property.value_type,
                    property.from_value ?? actor_current_property,
                    property.target_value
                )
            };

            if (i == 0) {
                transition.stopped.connect (call_on_stopped);
            }

            actor.add_transition (property.property, transition);
        }
    }

    private void call_on_stopped () {
        on_stopped (actor);
        unref ();
    }
}
