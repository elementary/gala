/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "io.elementary.gala.PantheonShellX11")]
public class Gala.PantheonShellX11 : GLib.Object {
    private static PantheonShellX11 instance;
    private static Meta.Display display;

    [DBus (visible = false)]
    public static void init (Meta.Display display) {
        PantheonShellX11.display = display;

        Bus.own_name (
            BusType.SESSION,
            "io.elementary.gala.PantheonShellX11",
            BusNameOwnerFlags.NONE,
            (connection) => {
                if (instance == null) {
                    instance = new PantheonShellX11 ();
                }

                try {
                    connection.register_object ("/io/elementary/gala/PantheonShellX11", instance);
                } catch (Error e) {
                    warning (e.message);
                }
            },
            () => {},
            () => warning ("Could not acquire name")
        );
    }

    public void set_anchor (string id, Pantheon.Desktop.Anchor anchor) throws GLib.Error {
        foreach (unowned var window in display.list_all_windows ()) {
            if (window.title == id) {
                ShellClientsManager.get_instance ().set_anchor (window, InternalUtils.anchor_to_side (anchor));
            }
        }
    }

    public void set_size (string id, int width, int height) throws GLib.Error {
        foreach (unowned var window in display.list_all_windows ()) {
            if (window.title == id) {
                ShellClientsManager.get_instance ().set_size (window, width, height);
            }
        }
    }

    public void set_hide_mode (string id, Pantheon.Desktop.HideMode hide_mode) throws GLib.Error {
        foreach (unowned var window in display.list_all_windows ()) {
            if (window.title == id) {
                ShellClientsManager.get_instance ().set_hide_mode (window, hide_mode);
            }
        }
    }

    public void make_centered (string id) throws GLib.Error {
        foreach (unowned var window in display.list_all_windows ()) {
            if (window.title == id) {
                ShellClientsManager.get_instance ().make_centered (window);
            }
        }
    }
}
