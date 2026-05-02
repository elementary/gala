/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public int main (string[] args) {
        Type[] test_types = {
            typeof (SetupTest),
            typeof (GestureControllerTest),
            typeof (PropertyTargetTest),
            typeof (SwipeTriggerTest),
            typeof (BackgroundBlurPerfTest),
        };

        Object[] tests = {};

        for (var i = 0; i < test_types.length; i++) {
            tests += GLib.Object.new_with_properties (test_types[i], {}, {});
        }

        Test.init (ref args);
        return Test.run ();
    }
}
