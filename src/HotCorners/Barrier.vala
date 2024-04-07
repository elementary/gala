/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

 /**
  * A pointer barrier supporting pressured activation.
  */
public class Gala.Barrier : Meta.Barrier {
    public signal void trigger ();

#if HAS_MUTTER46
    public Meta.Display display { owned get; construct; }
#endif

    public bool triggered { get; set; default = false; }

    public int trigger_pressure_threshold { get; construct; }
    public int release_pressure_threshold { get; construct; }
    public int retrigger_pressure_threshold { get; construct; }
    public int retrigger_delay { get; construct; }

    private uint32 triggered_time;
    private double pressure;

    /**
     * @param trigger_pressure_threshold The amount of pixels to travel additionally for
     * the barrier to trigger. Set to 0 to immediately activate.
     * @param retrigger_pressure_threshold The amount of pixels to travel additionally for
     * the barrier to trigger again. Set to int.MAX to disallow retrigger.
     */
    public Barrier (
        Meta.Display display,
        int x1,
        int y1,
        int x2,
        int y2,
        Meta.BarrierDirection directions,
        int trigger_pressure_threshold,
        int release_pressure_threshold,
        int retrigger_pressure_threshold,
        int retrigger_delay
    ) {
        Object (
            display: display,
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
            directions: directions,
            trigger_pressure_threshold: trigger_pressure_threshold,
            release_pressure_threshold: release_pressure_threshold,
            retrigger_pressure_threshold: retrigger_pressure_threshold,
            retrigger_delay: retrigger_delay
        );
    }

    construct {
        hit.connect (on_hit);
        left.connect (on_left);
    }

    private void on_hit (Meta.BarrierEvent event) {
        if (POSITIVE_X in directions || NEGATIVE_X in directions) {
            pressure += event.dx.abs ();
        } else {
            pressure += event.dy.abs ();
        }

        if (!triggered && pressure > trigger_pressure_threshold) {
            emit_trigger (event.time);
        }

        if (!triggered && pressure > release_pressure_threshold) {
            release (event);
        }

        if (triggered && pressure.abs () > retrigger_pressure_threshold && event.time > retrigger_delay + triggered_time) {
            emit_trigger (event.time);
        }
    }

    private void emit_trigger (uint32 time) {
        triggered = true;
        pressure = 0;
        triggered_time = time;

        trigger ();
    }

    private void on_left () {
        pressure = 0;
        triggered = false;
    }
}
