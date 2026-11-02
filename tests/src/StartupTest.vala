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
public class Gala.StartupTest : MutterTestCase {
    private WindowManagerGala? wm;

    construct {
        plugin_type = typeof (WindowManagerGala);

        add_test ("Test startup successful", test_startup_successful);
        add_test ("Test running successful", test_running_successful);
    }

    public override void set_up () {
        Test.log_set_fatal_handler (fatal_log_handler);

        base.set_up ();

        /* WindowManagerGala is [SingleInstance] so this way we get access to the actual one */
        wm = new WindowManagerGala ();
    }

    private bool fatal_log_handler (string? domain, LogLevelFlags level, string message) {
        return false;
    }

    /**
     * Check whether setup was successful, i.e. we have a
     * backend, clutter backend, context, etc.
     */
    private void test_startup_successful () {
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

    private void test_running_successful () {
        Timeout.add_seconds (5, () => {
            quit_main_loop ();
            return Source.REMOVE;
        });

        run_main_loop ();
    }
}
