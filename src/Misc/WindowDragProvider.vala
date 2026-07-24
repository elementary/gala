/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

[DBus (name = "io.elementary.desktop.wm.WindowDragProvider")]
public class Gala.WindowDragProvider : Object {
    private static GLib.Once<WindowDragProvider> instance;
    public static WindowDragProvider get_instance () {
        return instance.once (() => new WindowDragProvider ());
    }

    public signal void enter (uint64 window_id);
    public signal void motion (int x, int y);
    public signal void leave ();
    public signal void dropped ();

    internal void notify_enter (uint64 window_id) {
        enter (window_id);
    }

    internal void notify_motion (float x, float y) {
        motion ((int) x, (int) y);
    }

    internal void notify_leave () {
        leave ();
    }

    internal void notify_dropped () {
        dropped ();
    }
}
