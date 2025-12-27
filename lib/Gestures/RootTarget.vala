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

    public virtual float get_travel_distance (GestureAction for_action) {
        return 0.0f;
    }

    public void add_gesture_controller (GestureController controller) requires (controller.target == null) {
        controller.attached (this);
        weak_ref (controller.detached);
    }
}
