/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.DaemonManager : GLib.Object {
    [DBus (name = "org.pantheon.gala.daemon")]
    public interface Daemon: GLib.Object {
        public signal void window_menu_action_invoked (int action);

        public abstract async void show_window_menu (int display_width, int display_height, int x, int y, DaemonWindowMenuItem[] items) throws Error;
        public abstract async void show_desktop_menu (int display_width, int display_height, int x, int y) throws Error;
    }

    private const string DAEMON_DBUS_NAME = "org.pantheon.gala.daemon";
    private const string DAEMON_DBUS_OBJECT_PATH = "/org/pantheon/gala/daemon";
    private const int SPACING = 12;

    public signal void window_menu_action_invoked (int action);

    public Meta.Display display { get; construct; }

    private ManagedClient client;
    private Daemon? daemon_proxy = null;

    public DaemonManager (Meta.Display display) {
        Object (display: display);
    }

    construct {
        Bus.watch_name (BusType.SESSION, DAEMON_DBUS_NAME, BusNameWatcherFlags.NONE, daemon_appeared, lost_daemon);

        string[] args = { Meta.Util.is_wayland_compositor () ? "gala-daemon" : "gala-daemon-gtk3" };
        client = new ManagedClient (display, args);

        client.window_created.connect ((window) => {
            window.shown.connect (handle_daemon_window);
        });
    }

    private void handle_daemon_window (Meta.Window window) {
        if (window.title == null) {
            return;
        }

        var info = window.title.split ("-");

        if (info.length == 0) {
            critical ("Couldn't handle daemon window: No title provided");
            return;
        }

        switch (info[0]) {
            case "LABEL":
                if (info.length < 2) {
                    return;
                }

                var index = int.parse (info[1]);

                var monitor_geometry = display.get_monitor_geometry (index);
                window.move_frame (false, monitor_geometry.x + SPACING, monitor_geometry.y + SPACING);
                window.make_above ();
                break;

            case "MODAL":
#if HAS_MUTTER49
                window.set_type (Meta.WindowType.DOCK);
#elif HAS_MUTTER46
                client.wayland_client.make_dock (window);
#endif
                window.move_frame (false, 0, 0);
                window.make_above ();
                window.stick ();
                break;
        }
    }

    private void lost_daemon () {
        daemon_proxy = null;
    }

    private void daemon_appeared () {
        if (daemon_proxy == null) {
            Bus.get_proxy.begin<Daemon> (BusType.SESSION, DAEMON_DBUS_NAME, DAEMON_DBUS_OBJECT_PATH, 0, null, (obj, res) => {
                try {
                    daemon_proxy = Bus.get_proxy.end (res);
                    daemon_proxy.window_menu_action_invoked.connect ((action) => window_menu_action_invoked (action));
                } catch (Error e) {
                    warning ("Failed to get Menu proxy: %s", e.message);
                }
            });
        }
    }

    public async void show_background_menu (int x, int y) {
        if (daemon_proxy == null) {
            return;
        }

        int width, height;
        display.get_size (out width, out height);

        try {
            yield daemon_proxy.show_desktop_menu (width, height, x, y);
        } catch (Error e) {
            warning ("Error invoking MenuManager: %s", e.message);
        }
    }

    public async void show_window_menu (int x, int y, DaemonWindowMenuItem[] items) {
        if (daemon_proxy == null) {
            return;
        }

        int width, height;
        display.get_size (out width, out height);

        try {
            yield daemon_proxy.show_window_menu (width, height, x, y, items);
        } catch (Error e) {
            warning ("Error invoking MenuManager: %s", e.message);
        }
    }
}
