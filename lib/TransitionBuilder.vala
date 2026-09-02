/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.TransitionBuilder : Object {
    public enum ReducedMotionBehavior {
        /**
         * Adding the transition will be ignored i.e. a no op.
         * If you don't want the transition to run but still the final
         * value to be applied, use {@link APPLY} instead.
         */
        IGNORE,
        /**
         * The transition will not animate but the final value
         * will be applied immediately.
         */
        APPLY,
        /**
         * The transition will run normally.
         */
        RUN,
    }

    public Clutter.Actor actor { private get; construct; }
    public uint duration { private get; construct; }
    public Clutter.AnimationMode animation_mode { private get; construct; }

    private Clutter.TransitionGroup group;
    private bool transition_added = false;

    public TransitionBuilder (Clutter.Actor actor, uint duration, Clutter.AnimationMode animation_mode) {
        Object (actor: actor, duration: duration, animation_mode: animation_mode);
    }

    construct {
        group = new Clutter.TransitionGroup () {
            remove_on_complete = true,
            duration = duration,
        };
    }

    public void add_property (string name, Value to, ReducedMotionBehavior reduced_motion_behavior) {
        Value from = {};
        actor.get_property (name, ref from);
        add_property_with_from (name, from, to, reduced_motion_behavior);
    }

    public void add_property_with_from (
        string name, Value from, Value to, ReducedMotionBehavior reduced_motion_behavior
    ) requires (from.type () == to.type ()) {
        var reduce_motion = Utils.should_reduce_motion ();

        if (reduce_motion && reduced_motion_behavior == IGNORE) {
            return;
        }

        if (!Meta.Prefs.get_gnome_animations () || (reduce_motion && reduced_motion_behavior == APPLY)) {
            actor.set_property (name, to);
            return;
        }

        /* Set the property immediately to prevent flickering before the transition gets its first frame */
        actor.set_property (name, from);

        var interval = new Clutter.Interval.with_values (from.type (), from, to);

        var property_transition = new Clutter.PropertyTransition (name) {
            interval = interval,
            duration = duration,
            progress_mode = animation_mode,
        };
        group.add_transition (property_transition);

        transition_added = true;
    }

    public async void run () {
        if (!transition_added) {
            return;
        }

        var stopped_handler_id = group.stopped.connect (() => run.callback ());

        actor.add_transition (Uuid.string_random (), group);

        yield;

        group.disconnect (stopped_handler_id);
    }
}
