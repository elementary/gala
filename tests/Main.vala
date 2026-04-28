/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public int main (string[] args) {
        TestCase[] test_cases = {
            new SetupTest (),
            new GestureControllerTest (),
            new PropertyTargetTest (),
            new SwipeTriggerTest (),
        };

        Test.init (ref args);
        return Test.run ();
    }
}
