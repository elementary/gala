/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Daemon.KeyboardView : Object {
    public string name { get; construct; }
    public ListModel rows { get; construct; }
    public bool is_default { get; construct; }

    public KeyboardView (string name, ListModel rows, bool is_default = false) {
        Object (name: name, rows: rows, is_default: is_default);
    }
}
