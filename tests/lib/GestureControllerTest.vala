/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.MockRootTarget : Object, GestureTarget, RootTarget {
    public struct ReceivedUpdate {
        public UpdateType type;
        public GestureAction action;
        public double progress;
    }

    public Clutter.Actor? actor { get { return null; } }

    public Gee.LinkedList<ReceivedUpdate?> received_updates { get; construct; }

    construct {
        received_updates = new Gee.LinkedList<ReceivedUpdate?> ();
    }

    public override void propagate (UpdateType update_type, GestureAction action, double progress) {
        received_updates.add (ReceivedUpdate () {
            type = update_type,
            action = action,
            progress = progress
        });
    }
}

internal class Gala.MockGestureBackend : Object, GestureBackend {
}

public class Gala.GestureControllerTest : TestCase {
    private Settings gala_settings;

    private MockGestureBackend? backend;
    private GestureController? controller;
    private MockRootTarget? root_target;

    public GestureControllerTest () {
        Object (name: "GestureController");
    }

    construct {
        new GestureSettings (); // Ensure static variables are initialized

        // Make sure we configure swipe up to trigger multitasking view
        gala_settings = new GLib.Settings ("io.elementary.desktop.wm.gestures");
        gala_settings.delay ();
        gala_settings.set_string ("three-finger-swipe-up", "multitasking-view");

        add_test ("initial update", test_initial_update);
        add_test ("simple propagation", test_simple_propagation);
    }

    public override void set_up () {
        backend = new MockGestureBackend ();

        controller = new GestureController (MULTITASKING_VIEW, new MockWindowManager ());
        controller.enable_backend (backend);

        root_target = new MockRootTarget ();
        root_target.add_gesture_controller (controller);
    }

    public override void tear_down () {
        backend = null;
        controller = null;
        root_target = null;
    }

    private void test_initial_update () {
        // Test that we got the initial update when the controller was attached
        assert_cmpint (root_target.received_updates.size, EQ, 1);

        var sync_update = root_target.received_updates.poll ();

        assert_true (sync_update != null);
        assert_cmpint (sync_update.type, EQ, GestureTarget.UpdateType.UPDATE);
        assert_cmpint (sync_update.action, EQ, GestureAction.MULTITASKING_VIEW);
        assert_cmpfloat (sync_update.progress, EQ, 0.0);

        assert_true (root_target.received_updates.is_empty);
    }

    private void test_simple_propagation () {
        root_target.received_updates.poll (); // Remove the initial update

        // Test a simple propagation flow
        var gesture = new Gesture () {
            type = TOUCHPAD_SWIPE,
            direction = UP,
            fingers = 3,
        };

        var recognizing = backend.on_gesture_detected (gesture, 0);

        assert_true (recognizing);
        assert_true (root_target.received_updates.is_empty);
        assert_true (controller.recognizing);

        backend.on_begin (0, 0);

        assert_true (root_target.received_updates.size == 1);

        var update = root_target.received_updates.poll ();
        assert_true (update != null);
        assert_true (update.type == START);
        assert_true (update.action == MULTITASKING_VIEW);
        assert_true (update.progress == 0.0);

        backend.on_update (0.25, 0);
        backend.on_update (0.5, 0);

        assert_cmpfloat (controller.progress, EQ, 0.5);

        backend.on_update (0.75, 0);
        backend.on_update (1.0, 0);

        assert_true (root_target.received_updates.size == 4);

        for (int i = 0; i < 4; i++) {
            update = root_target.received_updates.poll ();
            assert_true (update != null);
            assert_true (update.type == UPDATE);
            assert_true (update.action == MULTITASKING_VIEW);
            assert_cmpfloat (update.progress, EQ, (i + 1) * 0.25);
        }

        backend.on_end (1.0, 0);

        assert_true (root_target.received_updates.size == 3);

        update = root_target.received_updates.poll ();
        assert_true (update != null);
        assert_true (update.type == UPDATE);
        assert_true (update.action == MULTITASKING_VIEW);
        assert_cmpfloat (update.progress, EQ, 1.0);

        update = root_target.received_updates.poll ();
        assert_true (update != null);
        assert_true (update.type == COMMIT);
        assert_true (update.action == MULTITASKING_VIEW);
        assert_cmpfloat (update.progress, EQ, 1.0);

        update = root_target.received_updates.poll ();
        assert_true (update != null);
        assert_true (update.type == END);
        assert_true (update.action == MULTITASKING_VIEW);
        assert_cmpfloat (update.progress, EQ, 1.0);

        assert_true (root_target.received_updates.is_empty);

        assert_false (controller.recognizing);
        assert_cmpfloat (controller.progress, EQ, 1.0);

        assert_finalize_object<MockRootTarget> (ref root_target);
        assert_finalize_object<GestureController> (ref controller);
        assert_finalize_object<MockGestureBackend> (ref backend);
    }
}

public int main (string[] args) {
    return new Gala.GestureControllerTest ().run (args);
}
