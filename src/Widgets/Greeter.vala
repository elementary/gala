/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Greeter : Clutter.Actor {
    public WindowManager wm { get; construct; }

    public Clutter.Actor window_group { get; private set; }
    public Clutter.Actor shell_group { get; private set; }

    private bool active;

    public Greeter (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        var background = new BackgroundContainer (wm.get_display ());
        window_group = new Clutter.Actor ();
        shell_group = new Clutter.Actor ();

        add_child (background);
        add_child (window_group);
        add_child (shell_group);

        reactive = true;
        visible = true;
        active = true;

        if (SessionSettings.should_set_xdg_current_desktop ()) {
            fade_in.begin ();
        } else {
            set_active.begin (false);
        }
    }

    public async void set_active (bool active) {
        if (this.active == active) {
            return;
        }

        this.active = active;

        remove_all_transitions ();

        visible = true;

        var transition_builder = new TransitionBuilder (this, 2000, EASE_IN);
        transition_builder.add_property ("opacity", active ? 255u : 0u);
        yield transition_builder.run ();

        visible = active;
    }

    private async void fade_in () {
        var fade_in_actor = new Clutter.Actor () {
            background_color = { 0, 0, 0, 255 },
        };
        fade_in_actor.add_constraint (new Clutter.BindConstraint (this, SIZE, 0));
        add_child (fade_in_actor);

        /* TODO: We might want to wait another second before we start the fade otherwise it's not really visible */

        var transition_builder = new TransitionBuilder (fade_in_actor, 2000, EASE);
        transition_builder.add_property ("opacity", 0u);
        yield transition_builder.run ();

        remove_child (fade_in_actor);
    }
}
