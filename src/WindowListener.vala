//
//  Copyright (C) 2014 Tom Beckmann
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

public class Gala.WindowListener : Object {
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
        if (instance != null)
            return;

        instance = new WindowListener ();

        foreach (unowned Meta.WindowActor actor in display.get_window_actors ()) {
            if (actor.is_destroyed ())
                continue;

            unowned Meta.Window window = actor.get_meta_window ();
            if (window.window_type == Meta.WindowType.NORMAL)
                instance.monitor_window (window);
        }

        display.window_created.connect ((window) => {
            if (window.window_type == Meta.WindowType.NORMAL)
                instance.monitor_window (window);
        });
    }

    public static unowned WindowListener get_default () requires (instance != null) {
        return instance;
    }

    public signal void window_no_longer_on_all_workspaces (Meta.Window window);

    private Gee.HashMap<Meta.Window, WindowGeometry?> unmaximized_state_geometry;

    private WindowListener () {
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
            case "maximized-vertically":
                window_maximized_changed (window);
                break;
            case "on-all-workspaces":
                window_on_all_workspaces_changed (window);
                break;
        }
    }

    private void window_on_all_workspaces_changed (Meta.Window window) {
        if (window.on_all_workspaces)
            return;

        window_no_longer_on_all_workspaces (window);
    }

    private void window_maximized_changed (Meta.Window window) {
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
