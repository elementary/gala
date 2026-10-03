/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.TransitionBuilder : Object {
    public Clutter.Actor actor { private get; construct; }
    public uint duration { private get; construct; }
    public Clutter.AnimationMode animation_mode { private get; construct; }

    private Clutter.TransitionGroup group;

    public TransitionBuilder (Clutter.Actor actor, uint duration, Clutter.AnimationMode animation_mode) {
        Object (actor: actor, duration: duration, animation_mode: animation_mode);
    }

    construct {
        group = new Clutter.TransitionGroup () {
            remove_on_complete = true,
            duration = duration,
        };
    }

    public void add_property (string name, Value to) {
        Value from = {};
        actor.get_property (name, ref from);
        add_property_with_from (name, from, to);
    }

    public void add_property_with_from (string name, Value from, Value to) requires (from.type () == to.type ()) {
        if (!Meta.Prefs.get_gnome_animations ()) {
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
    }

    /**
     * Runs the transitions added to #this. Returns true if the transitions
     * fully completed and false if they were somehow interrupted (e.g.
     * the actor was destroyed or remove all transitions was called).
     */
    public async bool run () {
        if (!Meta.Prefs.get_gnome_animations ()) {
            return true;
        }

        bool is_finished = false;
        var stopped_handler_id = group.stopped.connect ((_is_finished) => {
            is_finished = _is_finished;
            run.callback ();
        });

        actor.add_transition (Uuid.string_random (), group);

        yield;

        group.disconnect (stopped_handler_id);

        return is_finished;
    }
}
