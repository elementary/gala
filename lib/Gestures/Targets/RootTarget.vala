/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Gala.RootTarget : Object, GestureTarget {
    /**
     * The actor manipulated by the gesture. The associated frame clock
     * will be used for animation timelines.
     */
    public abstract Clutter.Actor? actor { get; }

    /**
     * Returns the distance the manipulated actor is expected to travel for
     * a 100% gesture. This is used so that the actor follows touch screen gestures 1:1.
     * This only applies to targets that expect to receive swipe gestures. Pinch gestures
     * are not affected.
     */
    public virtual double get_distance (GestureAction action) {
        return -1;
    }

    public void add_gesture_controller (GestureController controller) requires (controller.target == null) {
        controller.attached (this);
        weak_ref (controller.detached);
    }
}
