/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

public class Gala.SuperScrollAction : Clutter.Action {
    public signal void triggered (uint32 timestamp, double dx, double dy);

    public Meta.Display display { private get; construct; }

    public SuperScrollAction (Meta.Display display) {
        Object (display: display);
    }

    public override bool handle_event (Clutter.Event event) {
        if (
            event.get_type () == SCROLL &&
            (event.get_state() & display.compositor_modifiers) != 0
        ) {

            warning (event.get_device_type ().to_string ());

            double dx = 0.0, dy = 0.0;
            switch (event.get_scroll_direction ()) {
                case LEFT:
                    dx = -1.0;
                    break;
                case RIGHT:
                    dx = 1.0;
                    break;
                case UP:
                    dy = 1.0;
                    break;
                case DOWN:
                    dy = -1.0;
                    break;
                default:
                    break;
            }

            // TODO: support natural scroll settings

            triggered (event.get_time (), dx, dy);

            return Clutter.EVENT_STOP;
        }

        return Clutter.EVENT_PROPAGATE;
    }
}
