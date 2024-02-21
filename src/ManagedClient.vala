/**
 * Utility class that takes care of launching and restarting a subprocess.
 * On wayland this uses a WaylandClient and emits window_shown if a window for the client was shown
 * On X this just launches a normal subprocess
 */
public class Gala.ManagedClient : Object {
    public signal void window_created (Meta.Window window);

    public Meta.Display display { get; construct; }
    public string[] args { get; construct; }

    private Meta.WaylandClient? daemon_client;

    public ManagedClient (Meta.Display display, string[] args) {
        Object (display: display, args: args);
    }

    construct {
        if (Meta.Util.is_wayland_compositor ()) {
            start_wayland.begin ();

            display.window_created.connect ((window) => {
                if (daemon_client != null && daemon_client.owns_window (window)) {
                    window_created (window);
                }
            });
        } else {
            start_x.begin ();
        }
    }

    private async void start_wayland () {
        warning ("START WAYL:AND");
        var subprocess_launcher = new GLib.SubprocessLauncher (STDERR_PIPE | STDOUT_PIPE);
        try {
#if HAS_MUTTER44
            daemon_client = new Meta.WaylandClient (display.get_context (), subprocess_launcher);
#else
            daemon_client = new Meta.WaylandClient (subprocess_launcher);
#endif
            var subprocess = daemon_client.spawnv (display, args);

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
            var subprocess = new Subprocess.newv (args, NONE);
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