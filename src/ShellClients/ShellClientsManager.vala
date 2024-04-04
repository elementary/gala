/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellClientsManager : Object {
    public WindowManager wm { get; construct; }

    private NotificationsClient notifications_client;
    private PanelClient dock;

    public ShellClientsManager (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        notifications_client = new NotificationsClient (wm.get_display ());
        dock = new PanelClient (wm, {"io.elementary.dock"});
        dock.client.window_created.connect ((window) => {
            if (window.window_type != NORMAL) {
                return;
            }
            warning ("WINDOW CREATED");
            window.shown.connect (() => {
                dock.set_anchor (window, BOTTOM);
                //  dock.make_exclusive (window);
                dock.set_hide_mode (window, OVERLAPPING_WINDOW);
            });
            window.make_above ();
        });
    }
}
