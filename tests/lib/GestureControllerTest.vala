/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

internal class Gala.MockBackend : Object, GestureBackend {
}

internal class Gala.MockTrigger : Object, GestureTrigger {
    public GestureBackend backend { get; construct; }

    public MockTrigger (GestureBackend backend) {
        Object (backend: backend);
    }

    public bool triggers (Gesture gesture) {
        return true;
    }

    public void enable_backends (GestureController controller) {
        controller.enable_backend (backend);
    }
}

public class Gala.Propagation : Object {
    public GestureTarget.UpdateType update_type { get; construct; }
    public GestureAction action { get; construct; }
    public double progress { get; construct; }

    public Propagation (GestureTarget.UpdateType update_type, GestureAction action, double progress) {
        Object (update_type: update_type, action: action, progress: progress);
    }

    public void assert_equal (GestureTarget.UpdateType update_type, GestureAction action, double progress) {
        assert_cmpint (this.update_type, EQ, update_type);
        assert_cmpint (this.action, EQ, action);
        assert_cmpfloat (this.progress, EQ, progress);
    }
}

public class Gala.MockTarget : Object, GestureTarget, RootTarget {
    private Clutter.Actor _actor;
    public Clutter.Actor? actor { get { return _actor; } }

    public Gee.Queue<Propagation> propagations { get; private set; }

    public MockTarget (Clutter.Actor actor) {
        _actor = actor;
    }

    construct {
        propagations = new Gee.LinkedList<Propagation> ();
    }

    public void propagate (UpdateType update_type, GestureAction action, double progress) {
        propagations.add (new Propagation (update_type, action, progress));
    }

    public void print_propagation () {
        var prop = propagations.peek ();

        if (prop == null) {
            Test.message ("No propagation");
        } else {
            Test.message (
                "Propagation: update_type=%s, action=%s, progress=%f",
                prop.update_type.to_string (), prop.action.to_string (), prop.progress
            );
        }
    }

    public void assert_n_propagations (int n) {
        assert_cmpint (propagations.size, EQ, n);
    }

    public void assert_no_propagations () {
        assert_n_propagations (0);
    }

    public void assert_and_remove_propagation (GestureTarget.UpdateType update_type, GestureAction action, double progress) {
        var prop = propagations.poll ();

        assert_true (prop != null);

        prop.assert_equal (update_type, action, progress);
    }
}

public class Gala.GestureControllerTest : MutterTestCase {
    private MockBackend backend;
    private GestureController controller;
    private MockTarget target;

    public GestureControllerTest () {
        Object (name: "GestureControllerTest");
    }

    construct {
        add_test ("Test basic propagation", test_basic_propagation);
        add_test ("Test two immediate gotos", test_two_immediate_gotos);
    }

    public override void set_up () {
        base.set_up ();

        var actor = new Clutter.Actor ();
        stage.add_child (actor);

        backend = new MockBackend ();
        var trigger = new MockTrigger (backend);

        controller = new GestureController (CUSTOM);
        controller.add_trigger (trigger);

        target = new MockTarget (actor);

        target.assert_no_propagations ();

        target.add_gesture_controller (controller);

        target.assert_and_remove_propagation (UPDATE, CUSTOM, 0f);
        target.assert_no_propagations ();
    }

    public override void tear_down () {
        stage.remove_child (target.actor);

        backend = null;
        controller = null;
        target = null;

        base.tear_down ();
    }

    private void test_basic_propagation () {
        target.assert_no_propagations ();

        var gesture = new Gesture () {
            direction = UP
        };
        backend.on_gesture_detected (gesture, 0);

        assert_true (controller.recognizing);
        target.assert_no_propagations ();

        backend.on_begin (0, 0);

        target.assert_and_remove_propagation (START, CUSTOM, 0);
        target.assert_no_propagations ();

        backend.on_update (0.5, 0);

        target.assert_and_remove_propagation (UPDATE, CUSTOM, 0.5);
        target.assert_no_propagations ();

        backend.on_end (1.0, 0);

        assert_false (controller.recognizing);

        target.assert_n_propagations (3);
        target.assert_and_remove_propagation (UPDATE, CUSTOM, 1);
        target.assert_and_remove_propagation (COMMIT, CUSTOM, 1);
        target.assert_and_remove_propagation (END, CUSTOM, 1);
        target.assert_no_propagations ();

        assert_finalize_object (ref target);
        assert_finalize_object (ref controller);
        assert_finalize_object (ref backend);
    }

    /**
     * Make sure a goto cancels another goto even when the current progress is the progress of the second goto.
     * See https://github.com/elementary/gala/pull/2810 for a case where that was an issue.
     */
    private void test_two_immediate_gotos () {
        target.assert_no_propagations ();

        assert_cmpfloat (controller.progress, EQ, 0);

        controller.goto (1);

        target.assert_and_remove_propagation (START, CUSTOM, 0);
        target.assert_and_remove_propagation (COMMIT, CUSTOM, 1);
        target.assert_no_propagations ();

        controller.goto (0);

        target.assert_and_remove_propagation (COMMIT, CUSTOM, 0);
        target.assert_and_remove_propagation (END, CUSTOM, 0);
        target.assert_no_propagations ();

        Timeout.add (50, () => {
            assert_cmpfloat (controller.progress, EQ, 0);
            target.assert_no_propagations ();
            quit_main_loop ();
            return Source.REMOVE;
        });

        run_main_loop ();
    }
}
