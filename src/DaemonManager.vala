/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.DaemonManager : GLib.Object {
    private const string DAEMON_DBUS_NAME = "org.pantheon.gala.daemon";
    private const string DAEMON_DBUS_OBJECT_PATH = "/org/pantheon/gala/daemon";
    private const int SPACING = 12;

    [DBus (name = "org.pantheon.gala.daemon")]
    public interface Daemon: GLib.Object {
        public abstract async void set_display_size (int width, int height) throws DBusError, IOError;
        public abstract async void show_window_menu (WindowFlags flags, int x, int y) throws Error;
        public abstract async void show_desktop_menu (int x, int y) throws Error;
    }

    public Meta.Display display { get; construct; }

    private Meta.WaylandClient daemon_client;
    private Daemon? daemon_proxy = null;

    public DaemonManager (Meta.Display display) {
        Object (display: display);
    }

    construct {
        Bus.watch_name (BusType.SESSION, DAEMON_DBUS_NAME, BusNameWatcherFlags.NONE, () => daemon_appeared.begin (), lost_daemon);

        if (Meta.Util.is_wayland_compositor ()) {
            start_wayland.begin ();

            display.window_created.connect ((window) => {
                if (daemon_client.owns_window (window)) {
                    window.shown.connect (handle_daemon_window);
                }
            });
        } else {
            start_x.begin ();
        }

        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_display_size);
    }

    private async void start_wayland () {
        var subprocess_launcher = new GLib.SubprocessLauncher (NONE);
        try {
#if HAS_MUTTER44
            daemon_client = new Meta.WaylandClient (display.get_context (), subprocess_launcher);
#else
            daemon_client = new Meta.WaylandClient (subprocess_launcher);
#endif
            string[] args = {"gala-daemon"};
            var subprocess = daemon_client.spawnv (display, args);

            yield subprocess.wait_async ();
            warning ("Daemon exited");

            //Restart the daemon if it crashes
            Timeout.add_seconds (1, () => {
                start_wayland.begin ();
                return Source.REMOVE;
            });
        } catch (Error e) {
            warning ("Failed to create dock client: %s", e.message);
            return;
        }
    }

    private async void start_x () {
        try {
            var subprocess = new Subprocess (NONE, "gala-daemon");
            yield subprocess.wait_async ();
            warning ("Daemon exited");

            //Restart the daemon if it crashes
            Timeout.add_seconds (1, () => {
                start_x.begin ();
                return Source.REMOVE;
            });
        } catch (Error e) {
            warning ("Failed to create daemon subprocess with x: %s", e.message);
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

            case "MODAL":
                window.move_frame (false, 0, 0);
                window.make_above ();
                break;
        }
    }

    private void lost_daemon () {
        daemon_proxy = null;
    }

    private async void daemon_appeared () {
        if (daemon_proxy != null) {
            return;
        }

        try {
            daemon_proxy = yield Bus.get_proxy<Daemon> (BusType.SESSION, DAEMON_DBUS_NAME, DAEMON_DBUS_OBJECT_PATH, 0, null);
        } catch (Error e) {
            critical ("Failed to connect to daemon: %s", e.message);
            return;
        }

        yield update_display_size ();
    }

    private async void update_display_size () {
        if (daemon_proxy == null) {
            return;
        }

        int width, height;
        display.get_size (out width, out height);

        try {
            yield daemon_proxy.set_display_size (width, height);
        } catch (Error e) {
            warning ("Failed to update display size for daemon: %s", e.message);
        }
    }

    public async void show_background_menu (int x, int y) {
        if (daemon_proxy == null) {
            return;
        }

        try {
            yield daemon_proxy.show_desktop_menu (x, y);
        } catch (Error e) {
            warning ("Error invoking MenuManager: %s", e.message);
        }
    }

    public async void show_window_menu (WindowFlags flags, int x, int y) {
        if (daemon_proxy == null) {
            return;
        }

        try {
            yield daemon_proxy.show_window_menu (flags, x, y);
        } catch (Error e) {
            warning ("Error invoking MenuManager: %s", e.message);
        }
    }
}
