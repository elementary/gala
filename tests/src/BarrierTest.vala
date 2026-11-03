/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.BarrierTest : MutterTestCase {
    private Barrier? barrier;

    construct {
        add_test ("Test barrier finalizes", test_finalize_barrier);
    }

    public override void set_up () {
        base.set_up ();

        barrier = new Barrier (
            context.get_backend (),
            0,
            0,
            100,
            0,
            NEGATIVE_Y,
            0,
            5,
            double.MAX,
            1
        );

        assert_true (barrier != null);
    }

    public override void tear_down () {
        barrier = null;
        base.tear_down ();
    }

    private void test_finalize_barrier () {
        assert_true (barrier != null);
        assert_finalize_object (ref barrier);
    }
}
