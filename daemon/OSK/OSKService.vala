/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

[DBus (name = "io.elementary.OSK")]
public class Gala.Daemon.OSKService : Object {
    public signal void keyval_pressed (uint keyval);
    public signal void keyval_released (uint keyval);

    internal bool osk_enabled { get; private set; }
    internal IBus.InputPurpose osk_input_purpose { get; private set; }

    public void set_enabled (bool enabled) throws DBusError, IOError {
        warning ("Set enabled");
        osk_enabled = enabled;
    }

    public void set_input_purpose (IBus.InputPurpose input_purpose) throws DBusError, IOError {
        osk_input_purpose = input_purpose;
    }
}
