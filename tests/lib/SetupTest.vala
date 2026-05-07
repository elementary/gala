/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * More of a test for our testing infrastructure and not really
 * for testing any specific functionality of Gala.
 * Check that the MutterTestCase base class successfully sets up meta and clutter
 * and allows us to interact with it, e.g. by creating a Clutter actor.
 */
public class Gala.SetupTest : MutterTestCase {
    public SetupTest () {
        Object (name: "SetupTest");
    }

    construct {
        add_test ("Test setup successful", test_setup_successful);
        add_test ("Test main loop", test_main_loop);
        add_test ("Test main loop can run twice", test_main_loop);
        add_test ("Test actor animation", test_actor_animation);
    }

    /**
     * Check whether setup was successful, i.e. we have a
     * backend, clutter backend, context, etc.
     */
    private void test_setup_successful () {
        assert_true (context != null);

        var display = context.get_display ();
        assert_true (display != null);

        var backend = context.get_backend ();
        assert_true (backend != null);

        var stage = backend.get_stage ();
        assert_true (stage != null);
        assert_true (stage is Clutter.Stage);
        assert_true (this.stage == stage);

        // Creating an actor requires clutter machinery to be set up, so check this
        var actor = new Clutter.Actor ();
        assert_true (actor != null);
    }

    private void test_main_loop () {
        assert_true (context != null);

        var ran = false;

        Idle.add_once (() => ran = true);
        Idle.add_once (quit_main_loop);

        run_main_loop ();

        assert_true (ran);
    }

    private void test_actor_animation () {
        assert_true (stage != null);

        var frames = 0;

        var timeline = new Clutter.Timeline.for_actor (stage, 100);
        timeline.new_frame.connect (() => frames++);

        stage.show ();

        timeline.start ();

        Timeout.add (50, () => {
            assert_true (timeline.is_playing ());
            return Source.REMOVE;
        });

        Timeout.add (150, () => {
            assert_false (timeline.is_playing ());
            quit_main_loop ();
            return Source.REMOVE;
        });

        run_main_loop ();

        Test.message ("Got %d frames", frames);
        assert_cmpint (frames, GT, 0);
    }
}

public int main (string[] args) {
    return new Gala.SetupTest ().run (args);
}
