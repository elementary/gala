/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public int main (string[] args) {
        TestCase[] tests = {
            new SetupTest (),
            new GestureControllerTest (),
            new PropertyTargetTest (),
            new SwipeTriggerTest (),
        };

        Test.init (ref args);
        return Test.run ();
    }

    public void assert_finalize_object<G> (ref G data) {
        unowned var weak_pointer = data;
        ((Object) data).add_weak_pointer (&weak_pointer);
        data = null;
        assert_null (weak_pointer);
    }
}
