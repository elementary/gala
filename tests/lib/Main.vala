/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public int main (string[] args) {
        var test_name = args[1];

        var test_case = get_test_case (test_name);

        if (test_case == null) {
            warning ("TestCase %s not found", test_name);
            return 1;
        }

        return test_case.run (args);
    }

    private TestCase? get_test_case (string name) {
        Type[] test_types = {
            typeof (GestureControllerTest),
            typeof (PropertyTargetTest),
            typeof (SetupTest),
            typeof (SwipeTriggerTest),
        };

        foreach (var type in test_types) {
            if (type.name () == name) {
                return (TestCase) Object.new (type);
            }
        }

        return null;
    }
}
