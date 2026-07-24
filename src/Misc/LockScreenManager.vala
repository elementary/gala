/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.LockScreenManager : Object {
    public LockScreen lock_screen { private get; construct; }

    /**
     * To be set by the session locker in the future when we have an in session lock screen
     */
    public bool manually_locked { get; set; default = false; }

    public LockScreenManager (LockScreen lock_screen) {
        Object (lock_screen: lock_screen);
    }

    construct {
        notify["manually-locked"].connect (update_active);
        update_active ();
    }

    private void update_active () {
        var active = manually_locked || SessionSettings.is_greeter ();
        lock_screen.set_active.begin (active);
    }
}
