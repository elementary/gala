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
        "--virtual-monitor", "1280x720@60"
    };

    /*
     * Vala doesn't have async delegates so this has to match the signature of
     * an async test method. Then we can just cast the test method to this.
     */
    [CCode (instance_pos = 0)]
    public delegate void AsyncTestMethod (TaskReadyCallback callback);

    private class AsyncTestData {
        public AsyncTestMethod test_method;

        public AsyncTestData (AsyncTestMethod test_method) {
            this.test_method = test_method;
        }
    }

    protected Meta.Context? context { get; private set; }
    protected Clutter.Stage stage { get { return (Clutter.Stage) context.get_backend ().get_stage (); } }

    private HashTable<string, AsyncTestData> async_tests = new HashTable<string, AsyncTestData> (str_hash, str_equal);

    private MainLoop? main_loop;

    public override void set_up () {
        Test.log_set_fatal_handler (fatal_log_handler);

        if (context == null) {
            /* We can only create the context once, because Mutter doesn't allow recreating it */
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

        main_loop = new MainLoop (null, false);
    }

    /**
     * Override this method if you need to ignore certain fatal logs instead
     * of manually calling log_set_fatal_handler.
     * Also make sure to chain up to this implementation otherwise the test
     * will probably fail.
     */
    protected virtual bool fatal_log_handler (string? domain, LogLevelFlags level, string message) {
        if (domain == "libmutter" && FLAG_FATAL in level && "Failed to connect to colord daemon" in message) {
            /* Mutter sends a fatal log when failing to connect to colord but that doesn't matter for us */
            Test.message ("Got expected fatal colord log, not aborting");
            return false;
        }

        if (domain == "libmutter" && FLAG_FATAL in level && "Failed to make thread" in message) {
            /* Mutter sends a fatal log when failing to make a thread rt scheduled but that doesn't matter for us */
            Test.message ("Got expected fatal make thread rt log, not aborting");
            return false;
        }

        return true;
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

    /**
     * Adds an async test method. The method will be called while the main loop
     * is running and once the method ends the main loop is quit.
     * Note since vala doesn't allow async delegates you have to cast your async method
     * to AsyncTestMethod.
     */
    protected void add_async_test (string name, AsyncTestMethod test_method) {
        async_tests[name] = new AsyncTestData (test_method);
        add_test (name, run_async_test);
    }

    private void run_async_test () {
        var path = Test.get_path ();
        var name = Path.get_basename (path);

        assert_true (async_tests.contains (name));
        assert_true (main_loop != null);
        assert_true (!main_loop.is_running ());

        Idle.add (() => {
            AsyncTestData data = async_tests[name];
            data.test_method (() => quit_main_loop ());
            return Source.REMOVE;
        });

        run_main_loop ();
    }

    protected async void wait (int milliseconds) {
        assert_true (main_loop != null);
        assert_true (main_loop.is_running ());

        Timeout.add_once (milliseconds, () => {
            wait.callback ();
        });

        yield;
    }

    protected async void wait_idle () {
        assert_true (main_loop != null);
        assert_true (main_loop.is_running ());

        Idle.add_once (() => {
            wait_idle.callback ();
        });

        yield;
    }
}
