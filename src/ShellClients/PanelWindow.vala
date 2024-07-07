/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PanelWindow : Object {
    private const int BARRIER_OFFSET = 50; // Allow hot corner trigger

    private static HashTable<Meta.Window, Meta.Strut?> window_struts = new HashTable<Meta.Window, Meta.Strut?> (null, null);

    public WindowManager wm { get; construct; }
    public Meta.Window window { get; construct; }

    public bool hidden { get; private set; default = false; }

    public Meta.Side anchor;

    private Barrier? barrier;

    private PanelClone clone;

    private uint idle_move_id = 0;

    private int width = -1;
    private int height = -1;

    public PanelWindow (WindowManager wm, Meta.Window window, Meta.Side anchor) {
        Object (wm: wm, window: window);

        // Meta.Side seems to be currently not supported as GLib.Object property ...?
        // At least it always crashed for me with some paramspec, g_type_fundamental backtrace
        this.anchor = anchor;
    }

    construct {
        window.size_changed.connect (position_window);

        window.unmanaged.connect (() => {
            destroy_barrier ();

            if (window_struts.remove (window)) {
                update_struts ();
            }
        });

        window.stick ();

        clone = new PanelClone (wm, this);

        var monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (() => update_anchor (anchor));

        var workspace_manager = wm.get_display ().get_workspace_manager ();
        workspace_manager.workspace_added.connect (update_strut);
        workspace_manager.workspace_removed.connect (update_strut);
    }

#if HAS_MUTTER46
    public Mtk.Rectangle get_custom_window_rect () {
#else
    public Meta.Rectangle get_custom_window_rect () {
#endif
        var window_rect = window.get_frame_rect ();

        if (width > 0) {
            window_rect.width = width;
        }

        if (height > 0) {
            window_rect.height = height;
        }

        return window_rect;
    }

    public void set_size (int width, int height) {
        this.width = width;
        this.height = height;

        position_window ();
        set_hide_mode (clone.hide_mode); // Resetup barriers etc.
    }

    public void update_anchor (Meta.Side anchor) {
        this.anchor = anchor;

        position_window ();
        set_hide_mode (clone.hide_mode); // Resetup barriers etc.
    }

    private void position_window () {
        var display = wm.get_display ();
        var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
        var window_rect = get_custom_window_rect ();

        switch (anchor) {
            case TOP:
                position_window_top (monitor_geom, window_rect);
                break;

            case BOTTOM:
                position_window_bottom (monitor_geom, window_rect);
                break;

            default:
                warning ("Side not supported yet");
                break;
        }

        update_strut ();
    }

#if HAS_MUTTER45
    private void position_window_top (Mtk.Rectangle monitor_geom, Mtk.Rectangle window_rect) {
#else
    private void position_window_top (Meta.Rectangle monitor_geom, Meta.Rectangle window_rect) {
#endif
        var x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;

        move_window_idle (x, monitor_geom.y);
    }

#if HAS_MUTTER45
    private void position_window_bottom (Mtk.Rectangle monitor_geom, Mtk.Rectangle window_rect) {
#else
    private void position_window_bottom (Meta.Rectangle monitor_geom, Meta.Rectangle window_rect) {
#endif
        var x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;
        var y = monitor_geom.y + monitor_geom.height - window_rect.height;

        move_window_idle (x, y);
    }

    private void move_window_idle (int x, int y) {
        if (idle_move_id != 0) {
            Source.remove (idle_move_id);
        }

        idle_move_id = Idle.add (() => {
            window.move_frame (false, x, y);

            idle_move_id = 0;
            return Source.REMOVE;
        });
    }

    public void set_hide_mode (Pantheon.Desktop.HideMode hide_mode) {
        clone.hide_mode = hide_mode;

        destroy_barrier ();

        if (hide_mode == NEVER) {
            make_exclusive ();
        } else {
            unmake_exclusive ();
            setup_barrier ();
        }
    }

    private void make_exclusive () {
        update_strut ();
    }

    private void update_strut () {
        if (clone.hide_mode != NEVER) {
            return;
        }

        var rect = get_custom_window_rect ();

        Meta.Strut strut = {
            rect,
            anchor
        };

        window_struts[window] = strut;

        update_struts ();
    }

    private void update_struts () {
        var list = new SList<Meta.Strut?> ();

        foreach (var window_strut in window_struts.get_values ()) {
            list.append (window_strut);
        }

        foreach (var workspace in wm.get_display ().get_workspace_manager ().get_workspaces ()) {
            workspace.set_builtin_struts (list);
        }
    }

    private void unmake_exclusive () {
        if (window in window_struts) {
            window_struts.remove (window);
            update_struts ();
        }
    }

    private void destroy_barrier () {
        barrier = null;
    }

    private void setup_barrier () {
        var display = wm.get_display ();
        var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
        var scale = display.get_monitor_scale (display.get_primary_monitor ());
        var offset = InternalUtils.scale_to_int (BARRIER_OFFSET, scale);

        switch (anchor) {
            case TOP:
                setup_barrier_top (monitor_geom, offset);
                break;

            case BOTTOM:
                setup_barrier_bottom (monitor_geom, offset);
                break;

            default:
                warning ("Barrier side not supported yet");
                break;
        }
    }

#if HAS_MUTTER45
    private void setup_barrier_top (Mtk.Rectangle monitor_geom, int offset) {
#else
    private void setup_barrier_top (Meta.Rectangle monitor_geom, int offset) {
#endif
        barrier = new Barrier (
            wm.get_display ().get_context ().get_backend (),
            monitor_geom.x + offset,
            monitor_geom.y,
            monitor_geom.x + monitor_geom.width - offset,
            monitor_geom.y,
            POSITIVE_Y,
            0,
            0,
            int.MAX,
            int.MAX
        );

        barrier.trigger.connect (clone.show);
    }

#if HAS_MUTTER45
    private void setup_barrier_bottom (Mtk.Rectangle monitor_geom, int offset) {
#else
    private void setup_barrier_bottom (Meta.Rectangle monitor_geom, int offset) {
#endif
        barrier = new Barrier (
            wm.get_display ().get_context ().get_backend (),
            monitor_geom.x + offset,
            monitor_geom.y + monitor_geom.height,
            monitor_geom.x + monitor_geom.width - offset,
            monitor_geom.y + monitor_geom.height,
            NEGATIVE_Y,
            0,
            0,
            int.MAX,
            int.MAX
        );

        barrier.trigger.connect (clone.show);
    }
}
