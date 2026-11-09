/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * A exact clone of a window (same position and size). This is used for static
 * windows (e.g. on all workspaces or moving) and fades out while the multitasking view
 * is being opened.
 */
public class Gala.StaticWindowClone : Widget {
    public Meta.Window window { get; construct; }

    public StaticWindowClone (Meta.Window window) {
        Object (window: window);
    }

    construct {
        var window_actor = (Meta.WindowActor) window.get_compositor_private ();
        var clone = new Clutter.Clone (window_actor);
        add_child (clone);

        add_target (new PropertyTarget (MULTITASKING_VIEW, this, "opacity", typeof (uint8), (uint8) 255u, (uint8) 0u));

        window_actor.bind_property ("x", this, "x", SYNC_CREATE);
        window_actor.bind_property ("y", this, "y", SYNC_CREATE);

        set_pivot_point (0.5f, 0.5f);

        window.notify["maximized-horizontally"].connect (on_maximized_changed);
        window.notify["maximized-vertically"].connect (on_maximized_changed);
        on_maximized_changed ();
    }

    public override void update_progress (GestureAction action, double progress) {
        if (action == SWITCH_WORKSPACE && window.maximized_horizontally && window.maximized_vertically) {
            /* When moving a maximized window between workspaces the user can't see the animation
               because it is completely covered by the window. Therefore the user has no indication
               that something is actually happening. Solve this by scaling the window down a bit so
               that the user can see the animation. */

            /* We want the final value (`inverted`) to run between integer
               values from 0 to 1 at the half way point back to 0. */
            var normalized_progress = progress - Math.floor (progress);
            var absolute = (normalized_progress - 0.5).abs () * 2;
            var inverted = 1.0 - absolute;

            /* Then apply an exponential ease so that we get small very fast and only
               very late big again. This way the user sees most of the transition
               animation which carries the info that we are actually switching workspaces */
            var expo_eased = inverted == 1.0 ? 1.0 : 1.0 - Math.pow (2, -10 * inverted);

            var scale = 1.0 - (0.25 * expo_eased);
            set_scale (scale, scale);
        }
    }

    private void on_maximized_changed () {
        clear_effects ();

        if (window.maximized_horizontally && window.maximized_vertically) {
            var monitor_scale = window.display.get_monitor_scale (window.get_monitor ());
            add_effect (new ShadowEffect ("window", monitor_scale));
        } else {
            set_scale (1.0, 1.0);
        }
    }
}
