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
    private weak Clutter.Actor? actor;
    public Clutter.Orientation orientation { get; construct; }

    public SwipeTrigger (Clutter.Actor actor, Clutter.Orientation orientation) {
        Object (orientation: orientation);

        this.actor = actor;
        this.actor.weak_ref (on_actor_disposed);
    }

    ~SwipeTrigger () {
        if (actor != null) {
            actor.weak_unref (on_actor_disposed);
        }
    }

    private void on_actor_disposed () {
        actor = null;
    }

    internal bool triggers (Gesture gesture) {
        return (
            gesture.fingers == 1 && gesture.performed_on_device_type == TOUCHSCREEN_DEVICE && gesture.type == TOUCHPAD_SWIPE ||
            gesture.fingers == 2 && gesture.performed_on_device_type == TOUCHPAD_DEVICE && gesture.type == SCROLL
        );
    }

    internal void enable_backends (GestureController controller) {
        if (actor == null) {
            warning ("ScrollTrigger.enable_backends (): Can't add backends to controller: actor is null");
            return;
        }

        controller.enable_backend (new ScrollBackend (actor, orientation, new GestureSettings ()));
    }
}
