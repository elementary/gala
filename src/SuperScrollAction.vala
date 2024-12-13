/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Gala.SuperScrollAction : Clutter.Action {
    public signal void triggered ();

    public Meta.Display display { private get; construct; }

    public SuperScrollAction (Meta.Display display) {
        Object (display: display);
    }

    public override bool handle_event (Clutter.Event event) {
        if (event.get_type () == SCROLL && (event.get_state() & display.compositor_modifiers) != 0) {
            triggered ();

            return Clutter.EVENT_STOP;
        }

        return Clutter.EVENT_PROPAGATE;
    }
}
