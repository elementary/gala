/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2020, 2025, 2026 elementary, Inc. (https://elementary.io)
 */

public class Gala.ShutdownCurtain : Clutter.Actor {
    private unowned Clutter.Stage stage;
    public uint animation_duration { get; set construct; default = 300; }

    public ShutdownCurtain (Meta.Context context) {
        int screen_width, screen_height;
        context.get_display ().get_size (out screen_width, out screen_height);
        width = screen_width;
        height = screen_height;
        stage = (Clutter.Stage) context.get_display ().get_stage ();
    }

    public void animate () {
        var animation_thread = new Thread<void> ("tv-effect-animation", start);
        animation_thread.join ();
    }

    private void start () {
        int time = 0;
        var tv_effect = new TVEffect ();
        tv_effect.occlusion = 0;
        tv_effect.height = height;
        stage.add_effect_with_name (
            "tv-effect",
            tv_effect
        );

        while (time < animation_duration) {
            tv_effect.occlusion = (animation_duration - time) / (float) animation_duration;

            time += 16;
            Thread.usleep (16000);
        }

        stage.remove_effect_by_name ("tv-effect");
        Thread.usleep (2000);
    }
}
