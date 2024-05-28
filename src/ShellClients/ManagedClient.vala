/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * Utility class that takes care of launching and restarting a subprocess.
 * On wayland this uses a WaylandClient and emits window_created if a window for the client was created.
 * On X this just launches a normal subprocess and never emits window_created.
 */
public class Gala.ManagedClient : Object {
    public signal void window_created (Meta.Window window);

    public Meta.Display display { get; construct; }
    public string[] args { get; construct; }

    public Meta.WaylandClient? wayland_client { get; private set; }

    private Subprocess? subprocess;

    public ManagedClient (Meta.Display display, string[] args) {
        Object (display: display, args: args);
    }

    construct {
        if (Meta.Util.is_wayland_compositor ()) {
            start_wayland.begin ();

            display.window_created.connect ((window) => {
                if (wayland_client != null && wayland_client.owns_window (window)) {
                    window_created (window);

                    // We have to manage is alive manually since windows created by WaylandClients have our pid
                    // and we don't want to end our own process
                    window.notify["is-alive"].connect (() => {
                        if (!window.is_alive && subprocess != null) {
                            subprocess.force_exit ();
                            warning ("WaylandClient window became unresponsive, killing the client.");
                        }
                    });
                }
            });
        } else {
            start_x.begin ();
        }
    }

    private async void start_wayland () {
        var subprocess_launcher = new GLib.SubprocessLauncher (STDERR_PIPE | STDOUT_PIPE);
        try {
#if HAS_MUTTER44
            wayland_client = new Meta.WaylandClient (display.get_context (), subprocess_launcher);
#else
            wayland_client = new Meta.WaylandClient (subprocess_launcher);
#endif
            subprocess = wayland_client.spawnv (display, args);

            yield subprocess.wait_async ();

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
            subprocess = new Subprocess.newv (args, NONE);
            yield subprocess.wait_async ();

            //Restart the daemon if it crashes
            Timeout.add_seconds (1, () => {
                start_x.begin ();
                return Source.REMOVE;
            });
        } catch (Error e) {
            warning ("Failed to create daemon subprocess with x: %s", e.message);
        }
    }
}
