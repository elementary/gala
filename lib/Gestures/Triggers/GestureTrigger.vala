/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * Decides whether a gesture should be recognized. It also automatically enables
 * the necessary backends for the type of gesture.
 */
public interface Gala.GestureTrigger : Object {
    internal abstract bool triggers (Gesture gesture);
    internal abstract void enable_backends (GestureController controller);
}
