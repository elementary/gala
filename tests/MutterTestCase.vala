/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.MockPlugin : Meta.Plugin {

}

/**
 * Base class for tests that need to interact with Mutter and Clutter.
 * Sets up a Meta.Context, starts it, and provides access to the context
 * and stage for derived test classes. Note that the context and therefore
 * stage are shared between all tests and not recreated during set_up/tear_down,
 * because Mutter doesn't allow that.
 * If you need the main loop to run use {@link run_main_loop} and {@link quit_main_loop}
 * instead of {@link Meta.Context.run_main_loop} and {@link Meta.Context.terminate}.
 */
public abstract class Gala.MutterTestCase : Gala.TestCase {
    private const string[] MUTTER_ARGS = {
        "--wayland", "--headless", "--no-x11",
        "--wayland-display", "wayland-1",
        "--virtual-monitor", "1920x1080@60",
    };

    protected static Meta.Context? context { get; private set; }
    protected static Clutter.Stage? stage { get { return (Clutter.Stage) context?.get_backend ().get_stage (); } }
    protected bool force_stage_repaint { get; set; default = false; } 

    private bool stop_main_loop = false;
    private MainLoop? main_loop;

    construct {
        if (context != null) {
            return;
        }

        context = new Meta.Context ("");

        unowned var unowned_args = MUTTER_ARGS;
        try {
            context.configure (ref unowned_args);
        } catch (Error e) {
            assert_no_error (e);
        }

        context.set_plugin_gtype (typeof (MockPlugin));

        try {
            context.setup ();
        } catch (Error e) {
            assert_no_error (e);
        }

        try {
            context.start ();
        } catch (Error e) {
            assert_no_error (e);
        }
    }

    public override void set_up () {
        Test.log_set_fatal_handler ((domain, level, message) => {
            /* Mutter sends a fatal log when failing to connect to colord but that doesn't matter for us */
            Test.message ("Got fatal log, not aborting");
            return false;
        });

        main_loop = new MainLoop (null, false);
    }

    public override void tear_down () {
        main_loop = null;
    }

    protected void run_main_loop () {
        assert_true (main_loop != null);

        while (!stop_main_loop) {
            if (force_stage_repaint) {
                assert_true (stage != null);
                stage.queue_redraw ();
            }

            main_loop.get_context ().iteration (false);
        }

        stop_main_loop = false;
    }

    protected void quit_main_loop () {
        stop_main_loop = true;
    }
}
