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
        "--wayland", "--headless", "--sm-disable", "--no-x11",
        "--wayland-display", "wayland-1",
        "--virtual-monitor", "1280x720@60"
    };

    protected Meta.Context context { get; private set; }
    protected Clutter.Stage stage { get; private set; }

    private MainLoop? main_loop;

    construct {
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

        stage = (Clutter.Stage) context.get_backend ().get_stage ();
    }

    public override void set_up () {
        main_loop = new MainLoop (null, false);
    }

    public override void tear_down () {
        main_loop = null;
    }

    protected void run_main_loop () {
        assert_true (main_loop != null);
        main_loop.run ();
    }

    protected void quit_main_loop () {
        assert_true (main_loop != null);
        main_loop.quit ();
    }
}
