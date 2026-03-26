/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WindowMaximizer : ActorTarget, RootTarget {
    public WindowManager wm { get; construct; }

    public Clutter.Actor? actor { get { return tile; } }

    private Clutter.Actor tile;
    private GestureController controller;

    private Meta.Window? current_window;

    public WindowMaximizer (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        tile = new Clutter.Actor () {
            opacity = 200
        };
        Drawing.StyleManager.get_instance ().bind_property ("theme-accent-color", tile, "background-color", SYNC_CREATE);

        add_child (tile);

        controller = new GestureController (TOGGLE_MAXIMIZED);
        controller.add_trigger (new GlobalTrigger (TOGGLE_MAXIMIZED, wm));
        add_gesture_controller (controller);

    }

    public override void start_progress (GestureAction action) requires (action == TOGGLE_MAXIMIZED) {
        current_window = wm.get_display ().focus_window;

        if (current_window == null) {
            return;
        }

        visible = true;
        controller.progress = (double) current_window.maximized_horizontally;

        var workarea = wm.get_display ().get_workspace_manager ().get_active_workspace ().get_work_area_for_monitor (current_window.get_monitor ());
        var initial_rect = get_initial_rect (workarea);

        add_target (new PropertyTarget (TOGGLE_MAXIMIZED, tile, "x", typeof (float), (float) initial_rect.x, (float) workarea.x));
        add_target (new PropertyTarget (TOGGLE_MAXIMIZED, tile, "y", typeof (float), (float) initial_rect.y, (float) workarea.y));
        add_target (new PropertyTarget (TOGGLE_MAXIMIZED, tile, "width", typeof (float), (float) initial_rect.width, (float) workarea.width));
        add_target (new PropertyTarget (TOGGLE_MAXIMIZED, tile, "height", typeof (float), (float) initial_rect.height, (float) workarea.height));

        var window_actor = (Meta.WindowActor) current_window.get_compositor_private ();
        wm.window_group.set_child_above_sibling (this, window_actor);
    }

    private Mtk.Rectangle get_initial_rect (Mtk.Rectangle workarea) requires (current_window != null) {
        if (!current_window.maximized_horizontally) {
            return current_window.get_frame_rect ();
        }

        var unmaximized_geometry = WindowListener.get_default ().get_unmaximized_state_geometry (current_window);
        if (unmaximized_geometry != null) {
            return unmaximized_geometry.inner;
        }

        return { workarea.x + (workarea.width / 2), workarea.y + (workarea.height / 2), 0, 0 };
    }

    public override void commit_progress (GestureAction action, double commit) requires (action == TOGGLE_MAXIMIZED) {
        if (current_window == null) {
            return;
        }

        if (commit == 0 && current_window.maximized_horizontally) {
#if HAS_MUTTER49
            current_window.unmaximize ();
#else
            current_window.unmaximize (BOTH);
#endif
        } else if (commit == 1 && !current_window.maximized_horizontally) {
#if HAS_MUTTER49
            current_window.maximize ();
#else
            current_window.maximize (BOTH);
#endif
        }

        remove_all_targets ();
        visible = false;
        current_window = null;
    }
}
