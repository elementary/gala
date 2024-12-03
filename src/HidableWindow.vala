/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

/* Hides windows on both X11 and Wayland */
public class Gala.HidableWindow : GLib.Object {
    private const int OUT_OF_BOUNDS = 1000000;

    public Meta.Window window { get; construct; }

    /* Current window actor position or position before the window was moved out of bounds */
    public float x { get; private set; default = 0.0f; }
    public float y { get; private set; default = 0.0f; }

    /* Current window position or position before it was moved out of bounds */
    private int actual_x { get; private set; default = 0; }
    private int actual_y { get; private set; default = 0; }

    public HidableWindow (Meta.Window window) {
        Object (window: window);
    }

    construct {
        return_if_fail (window != null);

        var rect = window.get_frame_rect ();
        actual_x = rect.x;
        actual_y = rect.y;

        unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
        if (actor != null) {
            x = actor.x;
            y = actor.y;
        }

        window.position_changed.connect (on_window_position_changed);
    }

    private void on_window_position_changed () requires (window != null) {
        var rect = window.get_frame_rect ();

        if (rect.x != OUT_OF_BOUNDS) {
            actual_x = rect.x;

            Idle.add_once (() => {
                return_if_fail (window != null);
                unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
                return_if_fail (actor != null);
                x = actor.x;
            });
        }

        if (rect.y != OUT_OF_BOUNDS) {
            actual_y = rect.y;

            Idle.add_once (() => {
                return_if_fail (window != null);
                unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
                return_if_fail (actor != null);
                y = actor.y;
            });
        }
    }

    public void hide_window () requires (window != null) {
        unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
        if (actor != null) {
            actor.visible = false;
        }

        if (!Meta.Util.is_wayland_compositor ()) {
            window.move_frame (false, HidableWindow.OUT_OF_BOUNDS, HidableWindow.OUT_OF_BOUNDS);
        }
    }

    public void show_window () requires (window != null) {
        unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
        if (actor != null) {
            actor.visible = true;
        }

        if (!Meta.Util.is_wayland_compositor ()) {
            window.move_frame (false, actual_x, actual_y);
        }
    }

    public Mtk.Rectangle get_frame_rect () {
        if (window == null) {
            Mtk.Rectangle null_rect = { 0, 0, 0, 0 };
            return null_rect;
        }

        var window_rect = window.get_frame_rect ();
        window_rect.x = actual_x;
        window_rect.y = actual_y;

        return window_rect;
    }
}
