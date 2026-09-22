/*
 * Copyright 2024, 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

/**
 * Utility class that takes care of launching and restarting a subprocess.
 * On wayland this uses a WaylandClient and emits window_created if a window for the client was created.
 */
public class Gala.ManagedClient : Object {
    public signal void window_created (Meta.Window window);

    public Meta.Display display { private get; construct; }
    public string[] args { private get; construct; }

    private static Gee.List<unowned ManagedClient> instances = new Gee.LinkedList<unowned ManagedClient> (null);
    private Meta.WaylandClient? wayland_client;
    private Subprocess? subprocess;

    public ManagedClient (Meta.Display display, string[] args) {
        Object (display: display, args: args);
    }

    ~ManagedClient () {
        instances.remove (this);
    }

    construct {
        instances.add (this);

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
    }

    public static void make_dock (Meta.Window window) {
#if HAS_MUTTER49
        window.set_type (Meta.WindowType.DOCK);
#else
        make_dock_wayland (window);
#endif
    }

#if !HAS_MUTTER49
    private static void make_dock_wayland (Meta.Window window) {
        foreach (var client in instances) {
            if (client.wayland_client.owns_window (window)) {
                client.wayland_client.make_dock (window);
                break;
            }
        }
    }
#endif

    public static void make_desktop (Meta.Window window) {
#if HAS_MUTTER49
        window.set_type (Meta.WindowType.DESKTOP);
#else
        make_desktop_wayland (window);
#endif
    }

#if !HAS_MUTTER49
    private static void make_desktop_wayland (Meta.Window window) {
        foreach (var client in instances) {
            if (client.wayland_client.owns_window (window)) {
                client.wayland_client.make_desktop (window);
                break;
            }
        }
    }
#endif

    private async void start_wayland () {
        var subprocess_launcher = new GLib.SubprocessLauncher (INHERIT_FDS);
        try {
#if HAS_MUTTER49
            wayland_client = new Meta.WaylandClient.subprocess (display.get_context (), subprocess_launcher, args);
            subprocess = wayland_client.get_subprocess ();
#else
            wayland_client = new Meta.WaylandClient (display.get_context (), subprocess_launcher);
            subprocess = wayland_client.spawnv (display, args);
#endif

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
}
