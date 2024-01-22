/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.DaemonManager : Object {
    private const string DAEMON_DBUS_NAME = "org.pantheon.gala.daemon";
    private const string DAEMON_DBUS_OBJECT_PATH = "/org/pantheon/gala/daemon";
    private const int SPACING = 12;

    [DBus (name = "org.pantheon.gala.daemon")]
    public interface Daemon: GLib.Object {
        public abstract async void show_window_menu (WindowFlags flags, int x, int y) throws Error;
        public abstract async void show_desktop_menu (int x, int y) throws Error;
    }

    public Meta.Display display { get; construct; }

    private Daemon? daemon_proxy = null;

    private int x_position = 0;
    private int y_position = 0;

    public DaemonManager (Meta.Display display) {
        Object (display: display);
    }

    construct {
        Bus.watch_name (BusType.SESSION, DAEMON_DBUS_NAME, BusNameWatcherFlags.NONE, daemon_appeared, lost_daemon);
    }

    public void start () {
        if (Meta.Util.is_wayland_compositor ()) {
            start_wayland ();
        } else {
            start_x.begin ();
        }
    }

    private void start_wayland () {
        Meta.WaylandClient daemon_client;

        var subprocess_launcher = new GLib.SubprocessLauncher (NONE);
        try {
            daemon_client = new Meta.WaylandClient (subprocess_launcher);
            string[] args = {"gala-daemon"};
            daemon_client.spawnv (display, args);
        } catch (Error e) {
            warning ("Failed to create dock client: %s", e.message);
            return;
        }

        display.window_created.connect ((window) => {
            if (daemon_client.owns_window (window)) {
                window.shown.connect (handle_daemon_window);
            }
        });
    }

    private async void start_x () {
        try {
            var subprocess = new Subprocess (NONE, "gala-daemon");
            yield subprocess.wait_async ();

            //Restart the daemon if it crashes
            Timeout.add_seconds (1, () => {
                start_x.begin ();
                return Source.REMOVE;
            });
        } catch (Error e) {
            warning ("Failed to create daemon subprocess.");
        }
    }

    private void handle_daemon_window (Meta.Window window) {
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

            default:
                //Assume it's a menu since we can't set titles there
                window.move_frame (false, x_position, y_position);
                window.make_above ();
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

        x_position = x;
        y_position = y;
        
        try {
            yield daemon_proxy.show_desktop_menu (x, y);
        } catch (Error e) {
            message ("Error invoking MenuManager: %s", e.message);
        }
    }

    public async void show_window_menu (WindowFlags flags, int x, int y) {
        if (daemon_proxy == null) {
            return;
        }

        x_position = x;
        y_position = y;
        
        try {
            yield daemon_proxy.show_window_menu (flags, x, y);
        } catch (Error e) {
            message ("Error invoking MenuManager: %s", e.message);
        }
    }
}