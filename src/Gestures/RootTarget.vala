/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Gala.RootTarget : Object, GestureTarget {
    public void add_gesture_controller (GestureController controller) requires (controller.target == null) {
        controller.attached (this);
        weak_ref (controller.detached);
    }
}
