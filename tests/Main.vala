/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public int main (string[] args) {
        string? test_name = null;

        OptionEntry[] entries = {
            { "test-name", 't', NONE, STRING, ref test_name, null, null },
            { null }
        };

        var context = new OptionContext ("io.elementary.gala.tests");
        context.add_main_entries (entries, null);

        try {
            context.parse (ref args);
        } catch (Error e) {
            Test.message ("Option parsing failed: %s", e.message);
            return 1;
        }

        Type[] test_types = {
            typeof (SetupTest),
            typeof (GestureControllerTest),
            typeof (PropertyTargetTest),
            typeof (SwipeTriggerTest),
        };

        Object[] tests = {};

        for (var i = 0; i < test_types.length; i++) {
            unowned var test_type = test_types[i];

            var should_launch_test = test_name == null || test_type.name () == "Gala%s".printf (test_name);
            if (should_launch_test) {
                tests += GLib.Object.new_with_properties (test_type, {}, {});
            }
        }

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
