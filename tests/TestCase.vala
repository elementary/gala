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
    private Adaptor[] adaptors = new Adaptor[0];

    construct {
        suite = new GLib.TestSuite (name);
    }

    public int run (string[] args) {
        Test.init (ref args);
        TestSuite.get_root ().add_suite ((owned) suite);
        return Test.run ();
    }

    protected void add_test (string name, owned TestMethod test) {
        var adaptor = new Adaptor (name, (owned) test, this);
        adaptors += adaptor;

        var test_case = new GLib.TestCase (
            adaptor.name,
            adaptor.set_up,
            adaptor.run,
            adaptor.tear_down
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

    private class Adaptor : Object {
        public string name { get; construct; }

        private TestMethod test;
        private TestCase test_case;

        public Adaptor (string name, owned TestMethod test, TestCase test_case) {
            Object (name: name);

            this.test = (owned) test;
            this.test_case = test_case;
        }

        public void set_up (void* fixture) {
            test_case.set_up ();
        }

        public void run (void* fixture) {
            test ();
        }

        public void tear_down (void* fixture) {
            test_case.tear_down ();
        }
    }
}
