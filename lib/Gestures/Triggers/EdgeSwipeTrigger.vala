/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.EdgeSwipeTrigger : Object, GestureTrigger {
    private const int START_MARGIN = 20;

    public Meta.Display display { get; construct; }

    private Meta.Side side;

    public EdgeSwipeTrigger (Meta.Display display, Meta.Side side) {
        Object (display: display);

        /* Meta.Side is not supported as GObject property */
        this.side = side;
    }

    internal bool triggers (Gesture gesture) {
        return (
            (gesture.direction == RIGHT || gesture.direction == LEFT) && (side == LEFT || side == RIGHT) ||
            (gesture.direction == UP || gesture.direction == DOWN) && (side == TOP || side == BOTTOM)
        ) && (
            gesture.fingers == 1 && gesture.performed_on_device_type == TOUCHSCREEN_DEVICE && gesture.type == TOUCHPAD_SWIPE
        ) && (
            get_allowed_area ().contains_point (gesture.begin_centroid)
        );
    }

    private Graphene.Rect get_allowed_area () {
        var geometry = display.get_monitor_geometry (display.get_primary_monitor ());
        switch (side) {
            case Meta.Side.LEFT:
                return { { geometry.x, geometry.y }, { START_MARGIN, geometry.height } };
            case Meta.Side.RIGHT:
                return { { geometry.x + geometry.width - START_MARGIN, geometry.y }, { START_MARGIN, geometry.height } };
            case Meta.Side.TOP:
                return { { geometry.x, geometry.y }, { geometry.width, START_MARGIN } };
            case Meta.Side.BOTTOM:
                return { { geometry.x, geometry.y + geometry.height - START_MARGIN }, { geometry.width, START_MARGIN } };
            default:
                return { { 0, 0 }, { 0, 0 } };
        }
    }

    internal void enable_backends (GestureController controller) {
        var stage = display.get_compositor ().get_stage ();
        controller.enable_backend (new TouchScreenSwipeBackend (stage), this);
    }
}
