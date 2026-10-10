/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

private interface Gala.GestureBackend : Object {
    public signal bool on_gesture_detected (Gesture gesture, uint32 timestamp);
    public signal void on_begin (double percentage, uint64 time);
    public signal void on_update (double percentage, uint64 time);
    public signal void on_end (double percentage, uint64 time);

    /**
     * The gesture should be cancelled. The implementation should stop emitting
     * signals and reset any internal state. In particular it should not emit on_end.
     * The implementation has to make sure that any further events from the same gesture will
     * will be ignored. Once the gesture ends a new gesture should be treated as usual.
     */
    public virtual void cancel_gesture () { }

    /**
     * Tells this backend that it should not be mutually exclusive with the given other backend.
     * The usual implementation should check if it's of the same type and then group them accordingly,
     * e.g. call Clutter.Gesture.can_not_cancel or deliver events to the other backend directly.
     */
    public virtual void group_with (GestureBackend other) { }
}
