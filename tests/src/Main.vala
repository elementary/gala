/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public int main (string[] args) {
        TestRunner.register_test (typeof (TransitionBuilderTest));
        return TestRunner.run (args);
    }
}
