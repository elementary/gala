/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellClientsManager : Object {
    private static ShellClientsManager instance;

    public static void init (WindowManager wm) {
        if (instance != null) {
            return;
        }

        instance = new ShellClientsManager (wm);
    }

    public static ShellClientsManager? get_instance () {
        return instance;
    }

    public WindowManager wm { get; construct; }

    private NotificationsClient notifications_client;
    private ManagedClient[] protocol_clients = {};

    private GLib.HashTable<Meta.Window, PanelWindow> windows = new GLib.HashTable<Meta.Window, PanelWindow> (null, null);

    private ShellClientsManager (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        notifications_client = new NotificationsClient (wm.get_display ());

        // TODO: Launch clients e.g. from gsetting
        protocol_clients += new ManagedClient (wm.get_display (), { "io.elementary.dock" });
    }

    public void set_anchor (Meta.Window window, Meta.Side side) {
        if (window in windows) {
            windows[window].update_anchor (side);
            return;
        }

#if HAS_MUTTER46
        foreach (var client in protocol_clients) {
            if (client.wayland_client.owns_window (window)) {
                client.wayland_client.make_dock (window);
                break;
            }
        }
#endif
        // TODO: Return if requested by window that's not a trusted client?

        windows[window] = new PanelWindow (wm, window, side);

        // connect_after so we make sure the PanelWindow can destroy its barriers and struts
        window.unmanaged.connect_after (() => windows.remove (window));
    }

    /**
     * The size given here is only used for the hide mode. I.e. struts
     * and collision detection with other windows use this size. By default
     * or if set to -1 the size of the window is used.
     *
     * TODO: Maybe use for strut only?
     */
    public void set_size (Meta.Window window, int width, int height) {
        if (!(window in windows)) {
            warning ("Set anchor for window before size.");
            return;
        }

        windows[window].set_size (width, height);
    }

    public void set_hide_mode (Meta.Window window, PanelWindow.HideMode hide_mode) {
        if (!(window in windows)) {
            warning ("Set anchor for window before hide mode.");
            return;
        }

        windows[window].set_hide_mode (hide_mode);
    }
}
