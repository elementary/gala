/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * A trigger that triggers when a swipe gesture (2 fingers on touchpad, 1 finger on touchscreen)
 * has been recognized on the given actor with the given orientation.
 * It enables touchpad and (once supported) touchscreen backends for the given actor.
 */
public class Gala.SwipeTrigger : Object, GestureTrigger {
    public Clutter.Orientation orientation { get; construct; }
    private weak Clutter.Actor actor;

    public SwipeTrigger (Clutter.Actor actor, Clutter.Orientation orientation) {
        Object (orientation: orientation);

        this.actor = actor;
        actor.add_weak_pointer (&this.actor);
    }

    internal bool triggers (Gesture gesture) {
        return (
            gesture.fingers == 1 && gesture.performed_on_device_type == TOUCHSCREEN_DEVICE && gesture.type == TOUCHPAD_SWIPE ||
            gesture.fingers == 2 && gesture.performed_on_device_type == TOUCHPAD_DEVICE && gesture.type == SCROLL
        );
    }

    internal void enable_backends (GestureController controller) requires (actor != null) {
        controller.enable_backend (new ScrollBackend (actor, orientation, new GestureSettings ()));
    }
}
