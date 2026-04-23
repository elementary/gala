/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * A simple test case class. To use it inherit from it and add test methods
 * in the constructor using {@link add_test}. Override {@link set_up} and {@link tear_down}
 * to provide per-test-method setup and teardown. Then add a `main()` function
 * and return the result of {@link run}.
 */
public abstract class Gala.TestCase : Object {
    public delegate void TestMethod ();

    public string name { get; construct; }

    private GLib.TestSuite suite;

    construct {
        suite = new GLib.TestSuite (name);
    }

    public int run (string[] args) {
        Test.init (ref args);
        TestSuite.get_root ().add_suite ((owned) suite);
        return Test.run ();
    }

    protected void add_test (string name, TestMethod test) {
        var test_case = new GLib.TestCase (
            name,
            set_up,
            (TestFixtureFunc) test,
            tear_down
        );

        suite.add ((owned) test_case);
    }

    public virtual void set_up () {
    }

    public virtual void tear_down () {
    }

    public void assert_finalize_object<G> (ref G data) {
        unowned var weak_pointer = data;
        ((Object) data).add_weak_pointer (&weak_pointer);
        data = null;
        assert_null (weak_pointer);
    }
}
