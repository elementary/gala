/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class MockObject : Object {
    public int int_value { get; set; }
    public double double_value { get; set; }
}

public class Gala.PropertyTargetTest : TestCase {
    private MockObject? target;
    private PropertyTarget? default_int_prop_target;

    public PropertyTargetTest () {
        Object (name: "PropertyTarget");
    }

    construct {
        add_test ("simple propagation", test_simple_propagation);
        add_test ("double propagation", test_double_propagation);
        add_test ("other actions", test_other_actions);
        add_test ("finalize object first", test_finalize_object_first);
        add_test ("finalize property target first", test_finalize_property_target_first);
    }

    public override void set_up () {
        target = new MockObject ();
        default_int_prop_target = new PropertyTarget (
            MULTITASKING_VIEW,
            target,
            "int-value",
            typeof(int),
            0,
            10
        );
    }

    public override void tear_down () {
        target = null;
        default_int_prop_target = null;
    }

    private void test_simple_propagation () {
        assert_nonnull (&default_int_prop_target);
        assert_nonnull (&target);
        assert_cmpint (target.int_value, EQ, 0);

        default_int_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.0);
        assert_cmpint (target.int_value, EQ, 0);

        default_int_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.5);
        assert_cmpint (target.int_value, EQ, 5);

        default_int_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 1.0);
        assert_cmpint (target.int_value, EQ, 10);

        default_int_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.8);
        assert_cmpint (target.int_value, EQ, 8);

        default_int_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.3);
        assert_cmpint (target.int_value, EQ, 3);

        default_int_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.6);
        assert_cmpint (target.int_value, EQ, 6);

        assert_finalize_object<MockObject> (ref target);
        assert_finalize_object<PropertyTarget> (ref default_int_prop_target);
    }

    private void test_double_propagation () {
        var double_prop_target = new PropertyTarget (
            MULTITASKING_VIEW,
            target,
            "double-value",
            typeof(double),
            0.0,
            2.0
        );

        assert_nonnull (&double_prop_target);
        assert_nonnull (&target);
        assert_cmpfloat (target.double_value, EQ, 0.0);

        double_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.0);
        assert_cmpfloat (target.double_value, EQ, 0.0);

        double_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.5);
        assert_cmpfloat (target.double_value, EQ, 1.0);

        double_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 1.0);
        assert_cmpfloat (target.double_value, EQ, 2.0);

        double_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.8);
        assert_cmpfloat (target.double_value, EQ, 1.6);

        double_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.3);
        assert_cmpfloat (target.double_value, EQ, 0.6);

        double_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.6);
        assert_cmpfloat (target.double_value, EQ, 1.2);

        assert_finalize_object<MockObject> (ref target);
        assert_finalize_object<PropertyTarget> (ref double_prop_target);
    }

    private void test_other_actions () {
        assert_nonnull (&default_int_prop_target);

        assert_nonnull (&target);
        assert_cmpint (target.int_value, EQ, 0);

        default_int_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.0);
        assert_cmpint (target.int_value, EQ, 0);

        default_int_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 0.5);
        assert_cmpint (target.int_value, EQ, 5);

        default_int_prop_target.propagate (UPDATE, SWITCH_WORKSPACE, 1.0);
        assert_cmpint (target.int_value, EQ, 5);

        default_int_prop_target.propagate (UPDATE, CUSTOM, 1.0);
        assert_cmpint (target.int_value, EQ, 5);

        default_int_prop_target.propagate (UPDATE, MULTITASKING_VIEW, 1.0);
        assert_cmpint (target.int_value, EQ, 10);

        assert_finalize_object<MockObject> (ref target);
        assert_finalize_object<PropertyTarget> (ref default_int_prop_target);
    }

    private void test_finalize_object_first () {
        assert_nonnull (&target);
        assert_nonnull (&default_int_prop_target);

        // We can finalize the object before the property target because it doesn't hold a strong reference to it
        assert_finalize_object<MockObject> (ref target);
        assert_finalize_object<PropertyTarget> (ref default_int_prop_target);
    }

    private void test_finalize_property_target_first () {
        assert_nonnull (&target);
        assert_nonnull (&default_int_prop_target);

        // Finalize the property target before the object and make sure we don't have weak references
        // to the object (i.e. we don't crash when finalizing the object)
        assert_finalize_object<PropertyTarget> (ref default_int_prop_target);
        assert_finalize_object<MockObject> (ref target);
    }
}

public int main (string[] args) {
    return new Gala.PropertyTargetTest ().run (args);
}
