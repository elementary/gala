/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.SwipeTriggerTest : MutterTestCase {
    private Clutter.Actor? actor;
    private SwipeTrigger? trigger;

    public SwipeTriggerTest () {
        Object (name: "SwipeTriggerTest");
    }

    construct {
        add_test ("Test finalize trigger first", test_finalize_trigger_first);
        add_test ("Test finalize actor first", test_finalize_actor_first);
        add_test ("Test finalize actor and enable backend", test_finalize_actor_and_enable_backend);
    }

    public override void set_up () {
        actor = new Clutter.Actor ();
        trigger = new SwipeTrigger (actor, Clutter.Orientation.HORIZONTAL);
    }

    public override void tear_down () {
        trigger = null;
        actor = null;
    }

    private void test_finalize_trigger_first () {
        assert_finalize_object (ref trigger);
        assert_finalize_object (ref actor);
    }

    private void test_finalize_actor_first () {
        // We can finalize the actor first because the swipe trigger only holds a weak reference to it
        assert_finalize_object (ref actor);
        assert_finalize_object (ref trigger);
    }

    private void test_finalize_actor_and_enable_backend () {
        // We can finalize the actor first because the swipe trigger only holds a weak reference to it
        assert_finalize_object (ref actor);

        // Enabling the backend after the actor has been finalized should not cause a crash
        // but print a warning
        Test.expect_message (null, LEVEL_CRITICAL, "*assertion 'actor != null' failed");

        var controller = new GestureController (CUSTOM);
        trigger.enable_backends (controller);

        Test.assert_expected_messages ();

        assert_finalize_object (ref trigger);
    }
}
