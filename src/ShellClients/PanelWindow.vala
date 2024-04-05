/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.PanelWindow : Object {
    public enum HideMode {
        NEVER,
        MAXIMIZED_FOCUS_WINDOW,
        OVERLAPPING_FOCUS_WINDOW,
        OVERLAPPING_WINDOW,
        ALWAYS
    }

    private const int ANIMATION_DURATION = 250;
    private const int BARRIER_OFFSET = 50; // Allow hot corner trigger

    private static GLib.HashTable<Meta.Window, Meta.Strut?> window_struts = new GLib.HashTable<Meta.Window, Meta.Strut?> (null, null);

    public WindowManager wm { get; construct; }
    public Meta.Window window { get; construct; }

    public bool hidden { get; private set; default = false; }

    private Meta.Side anchor;
    private HideTracker hide_tracker;

    private Barrier? barrier;

    private SafeWindowClone? clone;

    public PanelWindow (WindowManager wm, Meta.Window window, Meta.Side anchor) {
        Object (wm: wm, window: window);

        this.anchor = anchor; // Meta.Side seems to be currently not supported as GLib.Object property ...?
    }

    construct {
        clone = new SafeWindowClone (window, true);
        wm.ui_group.add_child (clone);

        window.size_changed.connect (position_window);

        hide_tracker = new HideTracker (wm.get_display (), this, NEVER);

        window.unmanaged.connect (() => {
            if (window_struts.remove (window)) {
                update_struts ();
            }
        });

        window.stick ();

        var window_actor = (Meta.WindowActor) window.get_compositor_private ();
        bind_property ("hidden", window_actor, "visible", SYNC_CREATE | INVERT_BOOLEAN);

        window_actor.notify["x"].connect (() => {
            if (clone != null && (anchor == TOP || anchor == BOTTOM)) {
                clone.x = window_actor.x;
            }
        });

        window_actor.notify["y"].connect (() => {
            if (clone != null && (anchor == LEFT || anchor == RIGHT)) {
                clone.y = window_actor.y;
            }
        });
    }

    public void update_anchor (Meta.Side anchor) {
        this.anchor = anchor;

        position_window ();
        set_hide_mode (hide_tracker.hide_mode); // Resetup barriers etc.
    }

    private void position_window () {
        var display = wm.get_display ();
        var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
        var window_rect = window.get_frame_rect ();

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
        Idle.add (() => {
            window.move_frame (false, x, y);
            return Source.REMOVE;
        });
    }

    public void set_hide_mode (HideMode hide_mode) {
        hide_tracker.hide_mode = hide_mode;

        if (hide_mode != NEVER) {
            unmake_exclusive ();
            setup_barrier ();
        } else {
            make_exclusive ();
            barrier = null; //TODO: check whether that actually disables it
        }
    }

    private void make_exclusive () {
        window.size_changed.connect (update_strut);
        update_strut ();
    }

    private void update_strut () {
        var rect = window.get_frame_rect ();

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
            window.size_changed.disconnect (update_strut);
            window_struts.remove (window);
            update_struts ();
        }
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
            wm.get_display (),
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

        barrier.trigger.connect (show);
    }

#if HAS_MUTTER45
    private void setup_barrier_bottom (Mtk.Rectangle monitor_geom, int offset) {
#else
    private void setup_barrier_bottom (Meta.Rectangle monitor_geom, int offset) {
#endif
        barrier = new Barrier (
            wm.get_display (),
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

        barrier.trigger.connect (show);
    }

    private float calculate_clone_x (bool hidden) {
        var actor = (Meta.WindowActor) window.get_compositor_private ();

        switch (anchor) {
            case TOP:
            case BOTTOM:
                return actor.x;
            default:
                return 0;
        }
    }

    private float calculate_clone_y (bool hidden) {
        var actor = (Meta.WindowActor) window.get_compositor_private ();

        switch (anchor) {
            case TOP:
                return hidden ? actor.y - actor.height : actor.y;
            case BOTTOM:
                return hidden ? actor.y + actor.height : actor.y;
            default:
                return 0;
        }
    }

    public void hide () {
        if (hidden) {
            return;
        }

        hidden = true;

        if (anchor != TOP && anchor != BOTTOM) {
            warning ("Animated hide not supported for side yet.");
            return;
        }

        clone.visible = true;
        clone.set_position (calculate_clone_x (false), calculate_clone_y (false));

        clone.save_easing_state ();
        clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        clone.set_easing_duration (wm.enable_animations && !wm.workspace_view.is_opened () ? ANIMATION_DURATION : 0);
        clone.y = calculate_clone_y (true);
        clone.restore_easing_state ();
    }

    public void show () {
        if (!hidden) {
            return;
        }

        clone.save_easing_state ();
        clone.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
        clone.set_easing_duration (wm.enable_animations && !wm.workspace_view.is_opened () ? ANIMATION_DURATION : 0);
        clone.y = calculate_clone_y (false);
        clone.restore_easing_state ();

        Timeout.add (wm.enable_animations && !wm.workspace_view.is_opened () ? ANIMATION_DURATION : 0, () => {
            //  wm.ui_group.remove_child (clone);
            //  clone = null;
            clone.visible = false;
            hidden = false;
            hide_tracker.schedule_update (); // In case we already stopped hovering
            return Source.REMOVE;
        });
    }
}
