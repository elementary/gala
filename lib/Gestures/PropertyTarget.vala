/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PropertyTarget : Object, GestureTarget {
    public GestureAction action { get; construct; }
    // Don't take a reference since we are most of the time owned by the target
    public weak Object? target { get; private set; }
    public string property { get; construct; }

    public Clutter.Interval interval { get; construct; }

    public PropertyTarget (GestureAction action, Object target, string property, Type value_type, Value from_value, Value to_value) {
        Object (action: action, property: property, interval: new Clutter.Interval.with_values (value_type, from_value, to_value));

        this.target = target;
        this.target.weak_ref (on_target_disposed);
    }

    ~PropertyTarget () {
        if (target != null) {
            target.weak_unref (on_target_disposed);
        }
    }

    private void on_target_disposed () {
        target = null;
    }

    public void propagate (UpdateType update_type, GestureAction action, double progress) {
        if (target == null || update_type != UPDATE || action != this.action) {
            return;
        }

        target.set_property (property, interval.compute (progress));
    }
}
