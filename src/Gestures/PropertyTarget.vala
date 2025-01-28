/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PropertyTarget : Object, GestureTarget {
    public string id { get; construct; }

    private Clutter.Actor? _actor;
    public Clutter.Actor? actor { get { return _actor; } }

    /**
     * The property that will be animated. To be properly animated it has to be marked as
     * animatable in the Clutter documentation and should be numeric.
     */
    public string property { get; construct; }

    public Clutter.Interval interval { get; construct; }

    public PropertyTarget (string id, Clutter.Actor actor, string property, Type value_type, Value from_value, Value to_value) {
        Object (id: id, property: property, interval: new Clutter.Interval.with_values (value_type, from_value, to_value));

        _actor = actor;
    }

    public override void update (string id, double progress) {
        if (id != this.id) {
            return;
        }

        actor.set_property (property, interval.compute (progress));
    }
}
