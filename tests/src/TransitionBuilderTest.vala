/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.TransitionBuilderTest : MutterTestCase {
    construct {
        add_test ("test not ran", test_not_ran);
    }

    private void test_not_ran () {
        var actor = new Clutter.Actor ();
        var builder = new TransitionBuilder (actor, 500, EASE);

        assert_finalize_object<TransitionBuilder> (ref builder);
        assert_finalize_object<Clutter.Actor> (ref actor);
    }
}
