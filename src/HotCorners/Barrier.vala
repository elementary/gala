public class Gala.Barrier : Meta.Barrier {
    /**
     * In order to avoid accidental triggers, don't trigger the hot corner until
     * this threshold is reached.
     */
    private const int TRIGGER_PRESSURE_THRESHOLD = 50;

    /**
     * When the mouse pointer pressures the barrier without activating the hot corner,
     * release it when this threshold is reached.
     */
    private const int RELEASE_PRESSURE_THRESHOLD = 100;

    /**
     * When the mouse pointer pressures the hot corner after activation, trigger the
     * action again when this threshold is reached.
     * Only retrigger after a minimum delay (milliseconds) since original trigger.
     */
    private const int RETRIGGER_PRESSURE_THRESHOLD = 500;
    private const int RETRIGGER_DELAY = 1000;

    public signal void trigger ();

    public bool triggered { get; set; default = false; }
    public uint32 triggered_time { get; set; default = 0; }

    private double pressure;

    public Barrier (Meta.Display display, int x1, int y1, int x2, int y2, Meta.BarrierDirection directions) {
        Object (display: display, x1: x1, y1: y1, x2: x2, y2: y2, directions: directions);
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

        if (!triggered && pressure > TRIGGER_PRESSURE_THRESHOLD) {
            emit_trigger ();
        }

        if (!triggered && pressure > RELEASE_PRESSURE_THRESHOLD) {
            release (event);
        }

        if (triggered && pressure.abs () > RETRIGGER_PRESSURE_THRESHOLD && event.time > RETRIGGER_DELAY + triggered_time) {
            emit_trigger ();
        }
    }

    private void emit_trigger () {
        triggered = true;
        pressure = 0;

        trigger ();
    }

    private void on_left (Meta.BarrierEvent event) {
        pressure = 0;

        triggered = false;
    }
}
