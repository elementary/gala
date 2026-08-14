/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.WindowSwitcherManager : Object, GestureTarget, RootTarget {
    public WindowManager wm { private get; construct; }

    public Clutter.Actor? actor { get { return wm.stage; } }

    private GestureController controller;

    private WindowSwitcherProxy? window_switcher_proxy;

    public WindowSwitcherManager (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        controller = new GestureController (SWITCH_WINDOWS) {
            snap = false,
        };
        controller.add_trigger (new GlobalTrigger (SWITCH_WINDOWS, wm));

        add_gesture_controller (controller);

        Bus.watch_name (SESSION, "io.elementary.WindowSwitcher", NONE, () => on_name_appeared.begin (), on_name_vanished);
    }

    private async void on_name_appeared () {
        warning ("Window switcher appeared, getting proxy");
        try {
            window_switcher_proxy = yield Bus.get_proxy (SESSION, "io.elementary.WindowSwitcher", "/io/elementary/WindowSwitcher");
        } catch (Error e) {
            warning ("Failed to get window switcher proxy: %s", e.message);
        }
    }

    private void on_name_vanished () {
        window_switcher_proxy = null;
    }

    public void propagate (UpdateType type, GestureAction action, double progress) {
        warning ("propagate");
        if (window_switcher_proxy == null) {
            return;
        }

        warning ("Have proxy so do the stuff");
        switch (type) {
            case START:
                window_switcher_proxy.open.begin ();
                break;
            case UPDATE:
                window_switcher_proxy.set_progress.begin (progress);
                break;
            case END:
                window_switcher_proxy.close.begin ();
                break;
            default:
                break;
        }
    }
}
