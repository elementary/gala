/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

 public class Gala.PanelClient : GLib.Object {
    public WindowManager wm { get; construct; }
    public ManagedClient client { get; construct; }

    private GLib.HashTable<Meta.Window, PanelWindow> windows = new GLib.HashTable<Meta.Window, PanelWindow> (null, null);

    public PanelClient (WindowManager wm, string[] args) {
        Object (
            wm: wm,
            client: new ManagedClient (wm.get_display (), args)
        );
    }

    public void set_anchor (Meta.Window window, Meta.Side side) {
        if (window in windows) {
            windows[window].update_anchor (side);
            return;
        }

#if HAS_MUTTER_46
        client.wayland_client.make_dock (window);
#endif
        windows[window] = new PanelWindow (wm, window, side);

        // connect_after so we make sure the PanelWindow can destroy its barriers and struts
        window.unmanaged.connect_after (() => windows.remove (window));
    }

    public void set_hide_mode (Meta.Window window, PanelWindow.HideMode hide_mode) {
        if (!(window in windows)) {
            warning ("Set anchor for window before hide mode.");
            return;
        }

        windows[window].set_hide_mode (hide_mode);
    }
}