/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ActionFilterTest : MutterTestCase {
    public ActionFilterTest () {
        Object (name: "ActionFilterTest");
    }

    construct {
        add_test ("Test WindowManager filter_action without modal", test_no_modal);
        add_test ("Test WindowManager filter_action with modal", test_with_modal);
    }

    private void test_no_modal () {
        Idle.add (() => {
            foreach (var _action in ((EnumClass) typeof (ModalActions)).values) {
                assert_false (wm.filter_action ((ModalActions) _action.value));
            }

            quit_main_loop ();
            return Source.REMOVE;
        });

        run_main_loop ();
    }

    private void test_with_modal () {
        Idle.add (() => {
            assert_true (wm.stage != null);

            var actor = new Clutter.Actor ();
            wm.stage.add_child (actor);

            var proxy = wm.push_modal (actor, true);

            foreach (var _action in ((EnumClass) typeof (ModalActions)).values) {
                var action = (ModalActions) _action.value;

                proxy.allow_actions (action);
                assert_true (wm.filter_action (action));
            }

            wm.pop_modal (proxy);
            assert_finalize_object (ref proxy);

            wm.stage.remove_child (actor);
            assert_finalize_object (ref actor);

            quit_main_loop ();
            return Source.REMOVE;
        });

        run_main_loop ();
    }
}

public int main (string[] args) {
    return new Gala.ActionFilterTest ().run (args);
}
