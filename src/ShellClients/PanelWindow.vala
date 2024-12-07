/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PanelWindow : Object {
    private static HashTable<Meta.Window, Meta.Strut?> window_struts = new HashTable<Meta.Window, Meta.Strut?> (null, null);

    public WindowManager wm { get; construct; }
    public Meta.Window window { get; construct; }

    public Pantheon.Desktop.Anchor anchor { get; construct set; }

    private WindowPositioner window_positioner;

    private PanelClone clone;

    private int width = -1;
    private int height = -1;

    public PanelWindow (WindowManager wm, Meta.Window window, Pantheon.Desktop.Anchor anchor) {
        Object (wm: wm, window: window, anchor: anchor);
    }

    construct {
        window.unmanaging.connect (() => {
            if (window_struts.remove (window)) {
                update_struts ();
            }
        });

        window.stick ();

        clone = new PanelClone (wm, this);

        var display = wm.get_display ();

        var workspace_manager = display.get_workspace_manager ();
        workspace_manager.workspace_added.connect (update_strut);
        workspace_manager.workspace_removed.connect (update_strut);

        window.size_changed.connect (update_strut);
        window.position_changed.connect (update_strut);

        window_positioner = new WindowPositioner (display, window, WindowPositioner.Position.from_anchor (anchor));

        notify["anchor"].connect (() => window_positioner.position = WindowPositioner.Position.from_anchor (anchor));
    }

#if HAS_MUTTER45
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

            if (anchor == BOTTOM) {
                var geom = wm.get_display ().get_monitor_geometry (window.get_monitor ());
                window_rect.y = geom.y + geom.height - height;
            }
        }

        return window_rect;
    }

    public void set_size (int width, int height) {
        this.width = width;
        this.height = height;

        update_strut ();
    }

    public void set_hide_mode (Pantheon.Desktop.HideMode hide_mode) {
        clone.hide_mode = hide_mode;

        if (hide_mode == NEVER) {
            make_exclusive ();
        } else {
            unmake_exclusive ();
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
            side_from_anchor (anchor)
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

    private Meta.Side side_from_anchor (Pantheon.Desktop.Anchor anchor) {
        switch (anchor) {
            case BOTTOM:
                return BOTTOM;

            case LEFT:
                return LEFT;

            case RIGHT:
                return RIGHT;

            default:
                return TOP;
        }
    }
}
