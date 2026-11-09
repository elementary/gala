/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.TransitionBuilderTest : MutterTestCase {
    private Clutter.Actor? actor;
    private TransitionBuilder? builder;

    construct {
        add_async_test ("Test simple transition", (AsyncTestMethod) test_simple_transition);
        add_async_test ("Test life time", (AsyncTestMethod) test_life_time);
        add_test ("Test life time without run", test_life_time_without_run);
        add_async_test ("Test async run", (AsyncTestMethod) test_async_run);
    }

    public override void set_up () {
        base.set_up ();

        actor = new Clutter.Actor ();
        stage.add_child (actor);
        builder = new TransitionBuilder (actor, 500, LINEAR);

        assert_cmpuint (actor.opacity, EQ, 255);
    }

    public override void tear_down () {
        builder = null;

        stage.remove_child (actor);
        actor = null;
    }

    private async void test_simple_transition () {
        builder.add_property ("opacity", 0u, RUN);
        builder.run.begin ();

        yield wait (100);

        var opacity = actor.opacity;

        assert_cmpuint (opacity, GT, 20);
        assert_cmpuint (opacity, LT, 240);

        yield wait (500);

        assert_cmpuint (actor.opacity, EQ, 0);

        assert_finalize_object (ref builder);
    }

    /*
     * Test that the builder stays alive until the transition is complete
     * but then finalizes.
     */
    private async void test_life_time () {
        unowned var weak_builder = builder;

        builder.add_weak_pointer (&weak_builder);

        builder.add_property ("opacity", 0u, RUN);
        builder.run.begin ();

        builder = null;

        assert_true (weak_builder != null);

        yield wait (100);

        assert_true (weak_builder != null);
        assert_cmpuint (actor.opacity, GT, 20);
        assert_cmpuint (actor.opacity, LT, 240);

        yield wait (500);

        assert_true (weak_builder == null);
        assert_cmpuint (actor.opacity, EQ, 0);
    }

    private void test_life_time_without_run () {
        builder.add_property ("opacity", 0u, RUN);

        /* Check that the builder finalizes even if it's never run */
        assert_finalize_object (ref builder);
    }

    private async void test_async_run () {
        builder.add_property ("opacity", 0u, RUN);

        var finished = yield builder.run ();

        assert_true (finished);
        assert_cmpuint (actor.opacity, EQ, 0);

        yield wait_idle ();

        assert_finalize_object (ref builder);
    }
}
