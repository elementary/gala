/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2014 Tom Beckmann
 *                         2024 elementary, Inc. (https://elementary.io)
 */

public class Gala.WindowListener : GLib.Object {
    public struct WindowGeometry {
#if HAS_MUTTER45
        Mtk.Rectangle inner;
        Mtk.Rectangle outer;
#else
        Meta.Rectangle inner;
        Meta.Rectangle outer;
#endif
    }

    private static WindowListener? instance = null;

    public static void init (Meta.Display display) {
        if (instance != null) {
            return;
        }

        instance = new WindowListener ();

        foreach (unowned var window in display.list_all_windows ()) {
            if (window.window_type == Meta.WindowType.NORMAL) {
                instance.monitor_window (window);
            }
        }

        display.window_created.connect ((window) => {
            if (window.window_type == Meta.WindowType.NORMAL) {
                instance.monitor_window (window);
            }
        });
    }

    public static unowned WindowListener get_default () requires (instance != null) {
        return instance;
    }

    public signal void window_no_longer_on_all_workspaces (Meta.Window window);

    private Gee.HashMap<Meta.Window, WindowGeometry?> unmaximized_state_geometry;

    construct {
        unmaximized_state_geometry = new Gee.HashMap<Meta.Window, WindowGeometry?> ();
    }

    private void monitor_window (Meta.Window window) {
        window.notify.connect (window_notify);
        window.unmanaged.connect (window_removed);

        window_maximized_changed (window);
    }

    private void window_notify (Object object, ParamSpec pspec) {
        var window = (Meta.Window) object;

        switch (pspec.name) {
            case "maximized-horizontally":
                window_maximized_changed (window);
                break;
            case "on-all-workspaces":
                window_on_all_workspaces_changed (window);
                break;
        }
    }

    private void window_on_all_workspaces_changed (Meta.Window window) {
        if (window.on_all_workspaces) {
            return;
        }

        window_no_longer_on_all_workspaces (window);
    }

    private void window_maximized_changed (Meta.Window window) {
        if (!window.maximized_horizontally) {
            return;
        }

        WindowGeometry window_geometry = {};
        window_geometry.inner = window.get_frame_rect ();
        window_geometry.outer = window.get_buffer_rect ();

        unmaximized_state_geometry.@set (window, window_geometry);
    }

    public WindowGeometry? get_unmaximized_state_geometry (Meta.Window window) {
        return unmaximized_state_geometry.@get (window);
    }

    private void window_removed (Meta.Window window) {
        window.notify.disconnect (window_notify);
        window.unmanaged.disconnect (window_removed);
    }
}
