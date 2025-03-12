/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Gala.GestureBackend : Object {
    public signal bool on_gesture_detected (Gesture gesture, uint32 timestamp);
    public signal void on_begin (double delta, uint64 time);
    public signal void on_update (double delta, uint64 time);
    public signal void on_end (double delta, uint64 time);

    public virtual void prepare_gesture_handling () { }

    /**
     * The gesture should be cancelled. The implementation should stop emitting
     * signals and reset any internal state. In particular it should not emit on_end.
     * The implementation has to make sure that any further events from the same gesture will
     * will be ignored. Once the gesture ends a new gesture should be treated as usual.
     */
    public virtual void cancel_gesture () { }
}
