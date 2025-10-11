/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public interface Gala.GestureTarget : Object {
    public enum UpdateType {
        START,
        UPDATE,
        COMMIT,
        END
    }

    public virtual void propagate (UpdateType update_type, GestureAction action, double progress) { }
}
