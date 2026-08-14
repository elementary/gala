/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

[DBus (name = "io.elementary.WindowSwitcher")]
public interface Gala.WindowSwitcherProxy : Object {
    public signal void goto (double progress);

    public abstract async void open () throws DBusError, IOError;
    public abstract async void set_progress (double progress) throws DBusError, IOError;
    public abstract async void close () throws DBusError, IOError;
}
