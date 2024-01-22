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

    public void init_wayland () {
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
                setup_daemon_window (window);
            }
        });
    }

    private void setup_daemon_window (Meta.Window window) {
        var info = window.get_title ().split_set ("-");
        switch (info[0]) {
            case "MENU":
                window.shown.connect (() => {
                    window.move_frame (false, x_position, y_position);
                    window.make_above ();
                });
                break;

            case "LABEL":
                var index = int.parse (info[1]);
                var monitor_geometry = display.get_monitor_geometry (index);
                window.shown.connect (() => {
                    window.move_frame (false, monitor_geometry.x + SPACING, monitor_geometry.y + SPACING);
                    window.make_above ();
                });
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

    public void show_background_menu (int x, int y) {
        if (daemon_proxy == null) {
            return;
        }

        x_position = x;
        y_position = y;

        daemon_proxy.show_desktop_menu.begin (x, y, (obj, res) => {
            try {
                ((Daemon) obj).show_desktop_menu.end (res);
            } catch (Error e) {
                message ("Error invoking MenuManager: %s", e.message);
            }
        });
    }

    public void show_window_menu (Meta.Window window, Meta.WindowMenuType menu, int x, int y) {
        x_position = x;
        y_position = y;

        switch (menu) {
            case Meta.WindowMenuType.WM:
                if (daemon_proxy == null || window.get_window_type () == Meta.WindowType.NOTIFICATION) {
                    return;
                }

                WindowFlags flags = WindowFlags.NONE;
                if (window.can_minimize ())
                    flags |= WindowFlags.CAN_HIDE;

                if (window.can_maximize ())
                    flags |= WindowFlags.CAN_MAXIMIZE;

                var maximize_flags = window.get_maximized ();
                if (maximize_flags > 0) {
                    flags |= WindowFlags.IS_MAXIMIZED;

                    if (Meta.MaximizeFlags.VERTICAL in maximize_flags && !(Meta.MaximizeFlags.HORIZONTAL in maximize_flags)) {
                        flags |= WindowFlags.IS_TILED;
                    }
                }

                if (window.allows_move ())
                    flags |= WindowFlags.ALLOWS_MOVE;

                if (window.allows_resize ())
                    flags |= WindowFlags.ALLOWS_RESIZE;

                if (window.is_above ())
                    flags |= WindowFlags.ALWAYS_ON_TOP;

                if (window.on_all_workspaces)
                    flags |= WindowFlags.ON_ALL_WORKSPACES;

                if (window.can_close ())
                    flags |= WindowFlags.CAN_CLOSE;

                daemon_proxy.show_window_menu.begin (flags, x, y, (obj, res) => {
                    try {
                        ((Daemon) obj).show_window_menu.end (res);
                    } catch (Error e) {
                        message ("Error invoking MenuManager: %s", e.message);
                    }
                });
                break;
            case Meta.WindowMenuType.APP:
                // FIXME we don't have any sort of app menus
                break;
        }
    }
}