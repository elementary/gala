public class Gala.ShellComponentManager : Object {
    private GLib.HashTable<Meta.Window, Meta.Side> window_anchors;
    private GLib.HashTable<Meta.Window, Meta.Strut?> window_struts;
    private GLib.HashTable<Meta.Window, ManagedClient> window_to_client;
    private Meta.Display display;
    private string[] components = {"io.elementary.dock"};
    private ManagedClient[] clients = {};

    construct {
        window_anchors = new GLib.HashTable<Meta.Window, Meta.Side> (null, null);
        window_struts = new GLib.HashTable<Meta.Window, Meta.Strut?> (null, null);
        window_to_client = new GLib.HashTable<Meta.Window, ManagedClient> (null, null);
    }

    public void init (Meta.Display display) {
        this.display = display;

        foreach (var args in components) {
            var client = new ManagedClient (display, components);
            client.window_created.connect ((window) => {
                window_to_client[window] = client;
                window.unmanaged.connect (() => window_to_client.remove (window));
            });
            clients += client;
        }
    }

    public void set_anchor (Meta.Window window, Meta.Side side) {
#if !HAS_MUTTER46
        critical ("Mutter 46 required for wayland docks");
        return;
#else
        var client = window_to_client[window];

        if (client == null) {
            critical ("Window doesn't belong to a known client, can't set anchor.");
            return;
        }

        client.make_dock (window);

        position_window (window, side);

        window_anchors[window] = side;

        window.unmanaged.connect (() => {
            window_anchors.remove (window);
            if (window_struts.remove (window)) {
                update_struts ();
            }
        });
#endif
    }

    public void make_exclusive (Meta.Window window) {
        if (!(window in window_anchors)) {
            warning ("Set an anchor before making a window area exclusive.");
            return;
        }

        if (window in window_struts) {
            warning ("Window is already exclusive.");
            return;
        }

        window.size_changed.connect (update_strut);
        update_strut (window);
    }

    private void update_strut (Meta.Window window) {
        var rect = window.get_frame_rect ();

        Meta.Strut strut = {
            rect,
            window_anchors[window]
        };

        window_struts[window] = strut;

        update_struts ();
    }

    private void update_struts () {
        var list = new SList<Meta.Strut?> ();

        foreach (var window_strut in window_struts.get_values ()) {
            list.append (window_strut);
        }

        foreach (var workspace in display.get_workspace_manager ().get_workspaces ()) {
            workspace.set_builtin_struts (list);
        }
    }

    public void unmake_exclusive (Meta.Window window) {
        if (window in window_struts) {
            window.size_changed.disconnect (update_strut);
            window_struts.remove (window);
        }
    }

    private void position_window (Meta.Window window, Meta.Side side) {
        switch (side) {
            case TOP:
                break;
            default:
                break;
        }
    }
}
