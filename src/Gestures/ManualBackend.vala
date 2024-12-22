/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ManualBackend : Object, GestureBackend {
    public void start_action (GestureAction action, uint32 timestamp) {
        if (on_gesture_detected (new Gesture () {
            action = action
        }, timestamp)) {
            on_begin (0, timestamp);
            on_end (1, timestamp);
        }
    }
}
