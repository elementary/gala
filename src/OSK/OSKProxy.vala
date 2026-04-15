/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

[DBus (name = "io.elementary.OSK")]
public interface Gala.OSKProxy : Object {
    public signal void keyval_pressed (uint keyval);
    public signal void keyval_released (uint keyval);

    public async abstract void set_enabled (bool enabled) throws DBusError, IOError;
}
