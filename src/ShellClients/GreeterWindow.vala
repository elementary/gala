/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leo "lenemter" <lenemter@gmail.com>
 */

public class Gala.GreeterWindow : PositionedWindow, WindowWithStartAnimation {

    public GreeterWindow (Meta.Window window) {
        Object (window: window);
    }

    public void animate_start () {
        InternalUtils.wait_for_window_actor (window, (window_actor) => {
            window_actor.opacity = 0;
            window_actor.save_easing_state ();
            window_actor.set_easing_mode (Clutter.AnimationMode.EASE_IN);
            window_actor.set_easing_duration (Utils.get_animation_duration (200u));
            window_actor.opacity = 255;
            window_actor.restore_easing_state ();
        });
    }

    protected override void get_window_position (Mtk.Rectangle window_rect, out int x, out int y) {
        // We assume Greeter window is maximized
        x = window_rect.x;
        y = window_rect.y;
    }
}
