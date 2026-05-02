/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.BackgroundBlurPerfTest : MutterTestCase {
    private const float BLUR_RADIUS = 10.0f;
    private const float CLIP_RADIUS = 6.0f;
    private const float MONITOR_SCALE = 1.0f;

    private Clutter.Actor? actor;

    construct {
        force_stage_repaint = true;

        add_test ("Test performance on 5 sec", test_perf_5_sec);
    }

    public override void set_up () {
        base.set_up ();

        actor = new Clutter.Actor ();
        actor.set_size (1920, 1080);

        stage.add_child (actor);
    }

    public override void tear_down () {
        if (actor != null) {
            stage.remove_child (actor);
            actor = null;
        }
    }

    private void test_perf_5_sec () {
        assert_true (actor != null);
        assert_true (stage != null);

        uint64 total_frametime = 0; // in microseconds
        var frame_count = 0;
        uint64 start_clock = 0; // // in microseconds as well

        var before_paint_handler_id = stage.before_paint.connect ((view, frame) => {
            start_clock = GLib.get_monotonic_time ();
        });
        var after_paint_handler_id = stage.after_paint.connect ((view, frame) => {
            total_frametime += GLib.get_monotonic_time () - start_clock;
            frame_count++;
        });

        actor.add_effect (new BackgroundBlurEffect (BLUR_RADIUS, CLIP_RADIUS, MONITOR_SCALE));
        stage.show ();

        Timeout.add (5000, () => {
            quit_main_loop ();
            return Source.REMOVE;
        });

        run_main_loop ();

        var total_frametime_double = (double) total_frametime / 1000.0; // convert from microseconds to milliseconds
        Test.message (
            "Total frametime: %f ms --- Frames: %d --- Average: %f ms",
            total_frametime_double, frame_count, total_frametime_double / frame_count
        );

        stage.disconnect (before_paint_handler_id);
        stage.disconnect (after_paint_handler_id);
    }
}
