/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Gala.RootTarget : Object, GestureTarget {
    public void add_controller (GestureController controller) requires (controller.target == null) {
        controller.attached (this);

        // Bind the controller lifetime to #this lifetime
        controller.ref ();
        weak_ref (controller.unref);
    }
}
