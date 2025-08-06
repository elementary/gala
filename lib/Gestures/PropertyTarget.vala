/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PropertyTarget : Object, GestureTarget {
    public GestureAction action { get; construct; }

    //we don't want to hold a strong reference to the actor because we might've been added to it which would form a reference cycle
    private weak Clutter.Actor? _actor;
    public Clutter.Actor? actor { get { return _actor; } }

    public string property { get; construct; }

    public Clutter.Interval interval { get; construct; }

    public PropertyTarget (GestureAction action, Clutter.Actor actor, string property, Type value_type, Value from_value, Value to_value) {
        Object (action: action, property: property, interval: new Clutter.Interval.with_values (value_type, from_value, to_value));

        _actor = actor;
        _actor.destroy.connect (() => _actor = null);
    }

    public override void propagate (UpdateType update_type, GestureAction action, double progress) {
        if (update_type != UPDATE || action != this.action) {
            return;
        }

        actor.set_property (property, interval.compute (progress));
    }
}
