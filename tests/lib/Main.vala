/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public int main (string[] args) {
        TestRunner.register_test (typeof (GestureControllerTest));
        TestRunner.register_test (typeof (PropertyTargetTest));
        TestRunner.register_test (typeof (SetupTest));
        TestRunner.register_test (typeof (SwipeTriggerTest));
        return TestRunner.run (args);
    }
}
