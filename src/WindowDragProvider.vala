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
    private Meta.Window? previous_dock_window = null;
    private Meta.Window? window_waiting_to_move = null;

    public WindowDragProvider (Meta.Display display) {
        Object (display: display);
    }

    construct {
        display.grab_op_begin.connect ((grabbed_window, grab_op) => {
            if (grab_op != MOVING) {
                return;
            }

#if HAS_MUTTER48
            unowned var cursor_tracker = display.get_compositor ().get_backend ().get_cursor_tracker ();
#else
            unowned var cursor_tracker = display.get_cursor_tracker ();
#endif
            position_invalidated_id = cursor_tracker.position_invalidated.connect ((cursor_tracker) => {
                Graphene.Point pointer;
                cursor_tracker.get_pointer (out pointer, null);

                foreach (unowned var window in display.list_all_windows ()) {
                    if (window.window_type != DOCK) {
                        continue;
                    }
                        var buffer_rect = window.get_buffer_rect ();
#if HAS_MUTTER48
                    if (buffer_rect.contains_pointf (pointer.x, pointer.y)) {
#else
                    if (buffer_rect.contains_rect ({ (int) pointer.x, (int) pointer.y, 0, 0})) {
#endif
                        if (previous_dock_window != window) {
                            notify_enter (grabbed_window.get_id ());
                            previous_dock_window = window;
                        } else {
                            notify_motion ((int) pointer.x - buffer_rect.x, (int) pointer.y - buffer_rect.y);
                        }

                        return;
                    }
                }

                if (previous_dock_window != null) {
                    notify_leave ();
                    previous_dock_window = null;
                }
            });
        });

        display.grab_op_end.connect ((grabbed_window, grab_op) => {
            if (grab_op != MOVING) {
                return;
            }

            if (position_invalidated_id > 0) {
#if HAS_MUTTER48
                unowned var cursor_tracker = display.get_compositor ().get_backend ().get_cursor_tracker ();
#else
                unowned var cursor_tracker = display.get_cursor_tracker ();
#endif
                cursor_tracker.disconnect (position_invalidated_id);
                position_invalidated_id = 0;

                if (previous_dock_window != null) {
                    notify_dropped ();
                    notify_leave ();
                    previous_dock_window = null;
                    window_waiting_to_move = grabbed_window;
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

    /**
     * Handles centering the window on the workspace in case it was dragged directly to the dock.
     * If we don't do that, the dragged window will sit awkwardly at the bottom of the monitor.
     */
    internal void handle_move (uint64 uid) {
        if (uid != window_waiting_to_move.get_id ()) {
            warning ("WindowDragProvider: Windows id don't match");
            window_waiting_to_move = null;
            return;
        }

        var frame = window_waiting_to_move.get_frame_rect ();
        var monitor_geometry = display.get_monitor_geometry (window_waiting_to_move.get_monitor ());

        window_waiting_to_move.move_resize_frame (
            true,
            monitor_geometry.x + (monitor_geometry.width - frame.width) / 2,
            monitor_geometry.y + (monitor_geometry.height - frame.height) / 2,
            frame.width,
            frame.height
        );

        window_waiting_to_move = null;
    }
}
