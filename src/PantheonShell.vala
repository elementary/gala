public class Gala.PantheonShell : Object {
    public static void init (Meta.Display display) requires (instance == null) {
        instance = new PantheonShell (display);
    }

    private static PantheonShell? instance = null;

    public Meta.Display display { get; construct; }

    private Meta.WaylandClient dock_client;

    private PantheonShell (Meta.Display display) {
        Object (display: display);
    }

    construct {
        display.window_created.connect ((window) => {
            if (dock_client != null && dock_client.owns_window (window)) {
                setup_dock_window (window);
            }
        });

        var subprocess_launcher = new GLib.SubprocessLauncher (NONE);
        try {
            dock_client = new Meta.WaylandClient (subprocess_launcher);
            string[] args = {"io.elementary.dock"};
            dock_client.spawnv (display, args);
        } catch (Error e) {
            warning ("Failed to create dock client: %s", e.message);
        }
    }

    private void setup_dock_window (Meta.Window window) {
        window.notify["above"].connect (() => {
            if (!window.above) {
                window.make_above ();
            }
        });

        window.shown.connect (() => {
            window.move_frame (false, 0, 0);
            window.move_to_monitor (display.get_primary_monitor ());
            window.make_above ();
        });
    }
}
