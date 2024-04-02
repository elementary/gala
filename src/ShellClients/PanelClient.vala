/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

 public class Gala.PanelClient : GLib.Object {
    private static GLib.HashTable<Meta.Window, Meta.Strut?> window_struts = new GLib.HashTable<Meta.Window, Meta.Strut?> (null, null);

    public Meta.Display display { get; construct; }
    public ManagedClient client { get; construct; }

    private GLib.HashTable<Meta.Window, Meta.Side> window_anchors = new GLib.HashTable<Meta.Window, Meta.Side> (null, null);

    public PanelClient (Meta.Display display, string[] args) {
        Object (
            display: display,
            client: new ManagedClient (display, args)
        );
    }

    public void set_anchor (Meta.Window window, Meta.Side side) {
        window_anchors[window] = side;

#if HAS_MUTTER_46
        client.wayland_client.make_dock (window);
#endif

        position_window (window, side);
        window.size_changed.connect (() => position_window (window, side));

        window.unmanaged.connect (() => {
            window_anchors.remove (window);

            if (window_struts.remove (window)) {
                update_struts ();
            }
        });
    }

    private void position_window (Meta.Window window, Meta.Side side) {
        var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
        var window_rect = window.get_frame_rect ();

        switch (side) {
            case TOP:
                position_window_top (window, monitor_geom, window_rect);
                break;

            case BOTTOM:
                position_window_bottom (window, monitor_geom, window_rect);
                break;

            default:
                warning ("Side not supported yet");
                break;
        }
    }

    private void position_window_top (Meta.Window window, Meta.Rectangle monitor_geom, Meta.Rectangle window_rect) {
        var x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;

        move_window_idle (window, x, monitor_geom.y);
    }

    private void position_window_bottom (Meta.Window window, Meta.Rectangle monitor_geom, Meta.Rectangle window_rect) {
        var x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;
        var y = monitor_geom.y + monitor_geom.height - window_rect.height;

        move_window_idle (window, x, y);
    }

    private void move_window_idle (Meta.Window window, int x, int y) {
        Idle.add (() => {
            window.move_frame (false, x, y);
            return Source.REMOVE;
        });
    }

    public void make_exclusive (Meta.Window window) {
        if (!(window in window_anchors)) {
            warning ("Set an anchor before making a window area exclusive.");
            return;
        }

        if (window in window_struts) {
            warning ("Window is already exclusive.");
            return;
        }

        window.size_changed.connect (update_strut);
        update_strut (window);
    }

    private void update_strut (Meta.Window window) {
        var rect = window.get_frame_rect ();

        Meta.Strut strut = {
            rect,
            window_anchors[window]
        };

        window_struts[window] = strut;

        update_struts ();
    }

    private void update_struts () {
        var list = new SList<Meta.Strut?> ();

        foreach (var window_strut in window_struts.get_values ()) {
            list.append (window_strut);
        }

        foreach (var workspace in display.get_workspace_manager ().get_workspaces ()) {
            workspace.set_builtin_struts (list);
        }
    }

    public void unmake_exclusive (Meta.Window window) {
        if (window in window_struts) {
            window.size_changed.disconnect (update_strut);
            window_struts.remove (window);
            update_struts ();
        }
    }
}
