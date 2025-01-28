/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.SpringTimeline : Clutter.Timeline {
    private const double DELTA = 0.001;

    public signal void progress (double value);

    public double value_from { get; construct; }
    public double value_to { get; construct; }
    public double initial_velocity { get; construct; }

    public double damping { get; construct; }
    public double mass { get; construct; }
    public double stiffness { get; construct; }

    public double epsilon { get; construct; default = 0.0001; }

    public bool clamp { get; construct; }

    public SpringTimeline (Clutter.Actor actor, double value_from, double value_to, double initial_velocity, double damping_ratio, double mass, double stiffness) {
        var critical_damping = 2 * Math.sqrt (mass * stiffness);

        Object (
            actor: actor,
            value_from: value_from,
            value_to: value_to,
            initial_velocity: initial_velocity,
            damping: critical_damping * damping_ratio,
            mass: mass,
            stiffness: stiffness
        );

        duration = calculate_duration ();

        start ();
    }

    private bool approx (double a, double b, double epsilon) {
        return (a - b).abs () < epsilon || a == b;
    }

    private double oscillate (uint time, out double? velocity) {
        double b = damping;
        double m = mass;
        double k = stiffness;
        double v0 = initial_velocity;

        double t = time / 1000.0;

        double beta = b / (2 * m);
        double omega0 = Math.sqrt (k / m);

        double x0 = value_from - value_to;

        double envelope = Math.exp (-beta * t);

        /*
        * Solutions of the form C1*e^(lambda1*x) + C2*e^(lambda2*x)
        * for the differential equation m*ẍ+b*ẋ+kx = 0
        */

        /* Critically damped */
        /* double.EPSILON is too small for this specific comparison, so we use
        * FLT_EPSILON even though it's doubles */
        if (approx (beta, omega0, float.EPSILON)) {
            velocity = envelope * (-beta * t * v0 - beta * beta * t * x0 + v0);

            return value_to + envelope * (x0 + (beta * x0 + v0) * t);
        }

        /* Underdamped */
        if (beta < omega0) {
            double omega1 = Math.sqrt ((omega0 * omega0) - (beta * beta));

            velocity = envelope * (v0 * Math.cos (omega1 * t) - (x0 * omega1 + (beta * beta * x0 + beta * v0) / (omega1)) * Math.sin (omega1 * t));

            return value_to + envelope * (x0 * Math.cos (omega1 * t) + ((beta * x0 + v0) / omega1) * Math.sin (omega1 * t));
        }

        /* Overdamped */
        if (beta > omega0) {
            double omega2 = Math.sqrt ((beta * beta) - (omega0 * omega0));

            velocity = envelope * (v0 * Math.cosh (omega2 * t) + (omega2 * x0 - (beta * beta * x0 + beta * v0) / omega2) * Math.sinh (omega2 * t));

            return value_to + envelope * (x0 * Math.cosh (omega2 * t) + ((beta * x0 + v0) / omega2) * Math.sinh (omega2 * t));
        }

        warning ("Shouldnt reach here");
        velocity = 0;
        return 0;
    }

    private const int MAX_ITERATIONS = 20000;
    private uint get_first_zero () {
        /* The first frame is not that important and we avoid finding the trivial 0
        * for in-place animations. */
        uint i = 1;
        double y = oscillate (i, null);

        while ((value_to - value_from > double.EPSILON && value_to - y > epsilon) ||
            (value_from - value_to > double.EPSILON && y - value_to > epsilon)
        ) {
            if (i > MAX_ITERATIONS)
                return 0;

            y = oscillate (++i, null);
        }

        return i;
    }

    private uint calculate_duration () {
        double beta = damping / (2 * mass);
        double omega0;
        double x0, y0;
        double x1, y1;
        double m;

        int i = 0;

        if (approx (beta, 0, double.EPSILON) || beta < 0) {
            warning ("INFINITE");
            return -1;
        }

        if (clamp) {
            if (approx (value_to, value_from, double.EPSILON))
                return 0;

            return get_first_zero ();
        }

        omega0 = Math.sqrt (stiffness / mass);

        /*
        * As first ansatz for the overdamped solution,
        * and general estimation for the oscillating ones
        * we take the value of the envelope when it's < epsilon
        */
        x0 = -Math.log (epsilon) / beta;

        /* double.EPSILON is too small for this specific comparison, so we use
        * FLT_EPSILON even though it's doubles */
        if (approx (beta, omega0, float.EPSILON) || beta < omega0)
            return (uint) (x0 * 1000);

        /*
        * Since the overdamped solution decays way slower than the envelope
        * we need to use the value of the oscillation itself.
        * Newton's root finding method is a good candidate in this particular case:
        * https://en.wikipedia.org/wiki/Newton%27s_method
        */
        y0 = oscillate ((uint) (x0 * 1000), null);
        m = (oscillate ((uint) ((x0 + DELTA) * 1000), null) - y0) / DELTA;

        x1 = (value_to - y0 + m * x0) / m;
        y1 = oscillate ((uint) (x1 * 1000), null);

        while ((value_to - y1).abs () > epsilon) {
            if (i>1000)
                return 0;

            x0 = x1;
            y0 = y1;

            m = (oscillate ((uint) ((x0 + DELTA) * 1000), null) - y0) / DELTA;

            x1 = (value_to - y0 + m * x0) / m;
            y1 = oscillate ((uint) (x1 * 1000), null);
            i++;
        }

        return (uint) (x1 * 1000);
    }

    public override void new_frame (int time) {
        double velocity;
        double val = oscillate (time, out velocity);

        progress (val);
    }

    public override void stopped (bool is_finished) {
        if (is_finished) {
            progress (value_to);
        }
    }
}
