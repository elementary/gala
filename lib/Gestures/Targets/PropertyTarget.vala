/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PropertyTarget : Object, GestureTarget {
    static construct {
        /* The default progress func starts from the beginning when it overflows but we want
           to clamp. E.g. when the multitasking view overshoots we want the opacity
           to stay at max and not switch to 0 again. */
        Clutter.Interval.register_progress_func (typeof (uint8), uint8_progress_func);
    }

    private static bool uint8_progress_func (Value a, Value b, double progress, Value result) {
        if (a.type () != typeof (uint8) || b.type () != typeof (uint8)) {
            return false;
        }

        var a_val = a.get_uchar ();
        var b_val = b.get_uchar ();

        var res = (uint8) (a_val + progress * b_val).clamp (0, 255);
        result.set_uchar (res);
        return true;
    }

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
        if (target == null || action != this.action) {
            return;
        }

        if (update_type == START && target is Clutter.Actor) {
            unowned var target_actor = (Clutter.Actor) target;

            // We need to stop any transitions as they may interfere with the gesture
            target_actor.remove_transition (property);
        } else if (update_type == UPDATE) {
            target.set_property (property, interval.compute (progress));
        }
    }
}
