public class Gala.PantheonShell : Object {
    private Meta.Display display;
    private Meta.WaylandClient dock_client;

    private static PantheonShell instance;

    public static PantheonShell get_default () requires (instance != null) {
        return instance;
    }

    public static void init (Meta.Display display) {
        instance = new PantheonShell ();
        instance.initialize (display);
    }

    public void initialize (Meta.Display display) {
        this.display = display;
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
        // window.stick ();
        window.shown.connect (() => {
            window.move_frame (false, 0, 0);
            window.move_to_monitor (display.get_primary_monitor ());
        });
    }
}
