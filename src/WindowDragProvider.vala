/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

[DBus (name = "io.elementary.desktop.wm.WindowDragProvider")]
public class Gala.WindowDragProvider : Object {
    private static GLib.Once<WindowDragProvider> instance;
    public static unowned WindowDragProvider get_instance (Meta.Display display) {
        return instance.once (() => { return new WindowDragProvider (display); });
    }

    public signal void enter (uint64 window_id);
    public signal void motion (int x, int y);
    public signal void leave ();
    public signal void dropped ();

    [DBus (visible = false)]
    public Meta.Display display { private get; construct; }

    private ulong position_invalidated_id = 0;
    private Meta.Window? previous_window = null;

    public WindowDragProvider (Meta.Display display) {
        Object (display: display);
    }

    construct {
        display.grab_op_begin.connect ((grabbed_window, grab_op) => {
            if (grab_op == MOVING) {
                unowned var cursor_tracker = display.get_cursor_tracker ();
                position_invalidated_id = cursor_tracker.position_invalidated.connect (() => {
                    Graphene.Point pointer;
                    cursor_tracker.get_pointer (out pointer, null);

                    foreach (unowned var window in display.list_all_windows ()) {
                        if (window.window_type == DOCK) {
                            var buffer_rect = window.get_buffer_rect ();
    #if HAS_MUTTER48
                            if (buffer_rect.contains_pointf (pointer.x, pointer.y)) {
    #else
                            if (buffer_rect.contains_rect ({ (int) pointer.x, (int) pointer.y, 0, 0})) {
    #endif
                                if (previous_window != window) {
                                    notify_enter (grabbed_window.get_id ());
                                    previous_window = window;
                                } else {
                                    notify_motion ((int) pointer.x - buffer_rect.x, (int) pointer.y - buffer_rect.y);
                                }

                                return;
                            }
                        }
                    }

                    if (previous_window != null) {
                        notify_leave ();
                        previous_window = null;
                    }
                });
            }
        });

        display.grab_op_end.connect ((window, grab_op) => {
            if (position_invalidated_id > 0) {
                unowned var cursor_tracker = display.get_cursor_tracker ();
                cursor_tracker.disconnect (position_invalidated_id);
                position_invalidated_id = 0;

                if (previous_window != null) {
                    notify_dropped ();
                    previous_window = null;
                }
            }
        });
    }

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
