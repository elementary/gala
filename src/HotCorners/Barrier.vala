/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

 /**
  * A pointer barrier supporting pressured activation.
  */
public class Gala.Barrier : Object {
    public signal void trigger ();

    public bool triggered { get; set; default = false; }

    public int trigger_pressure_threshold { get; construct; }
    public int release_pressure_threshold { get; construct; }
    public int retrigger_pressure_threshold { get; construct; }
    public int retrigger_delay { get; construct; }

    private Meta.Barrier barrier;

    private uint32 triggered_time;
    private double pressure;

    /**
     * @param trigger_pressure_threshold The amount of pixels to travel additionally for
     * the barrier to trigger. Set to 0 to immediately activate.
     * @param retrigger_pressure_threshold The amount of pixels to travel additionally for
     * the barrier to trigger again. Set to int.MAX to disallow retrigger.
     */
    public Barrier (
        Meta.Backend backend,
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
            trigger_pressure_threshold: trigger_pressure_threshold,
            release_pressure_threshold: release_pressure_threshold,
            retrigger_pressure_threshold: retrigger_pressure_threshold,
            retrigger_delay: retrigger_delay
        );

        try {
            barrier = new Meta.Barrier (backend, x1, y1, x2, y2, directions, Meta.BarrierFlags.NONE);
            barrier.hit.connect (on_hit);
            barrier.left.connect (on_left);
        } catch (Error e) {
            warning ("Failed to create Meta Barrier");
        }
    }

    ~Barrier () {
        barrier.destroy ();
    }

    private void on_hit (Meta.BarrierEvent event) {
        if (POSITIVE_X in barrier.directions || NEGATIVE_X in barrier.directions) {
            pressure += event.dx.abs ();
        } else {
            pressure += event.dy.abs ();
        }

        if (!triggered && pressure > trigger_pressure_threshold) {
            emit_trigger (event.time);
        }

        if (!triggered && pressure > release_pressure_threshold) {
            barrier.release (event);
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
