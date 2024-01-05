[SingleInstance]
public class Gala.PanelManager : Object {
    private static GLib.Once<PanelManager> instance;
    public static PanelManager get_default () {
        return instance.once (() => {return new PanelManager ();});
    }

    private GLib.HashTable<Meta.Window, Meta.Side> window_anchors;
    private GLib.HashTable<Meta.Window, Meta.Strut?> window_struts;
    private Meta.Display display;

    construct {
        window_anchors = new GLib.HashTable<Meta.Window, Meta.Side> (null, null);
        window_struts = new GLib.HashTable<Meta.Window, Meta.Strut?> (null, null);
    }

    public void init (Meta.Display display) {
        this.display = display;
    }

    public void set_anchor (Meta.Window window, Meta.Side side) {
        //TODO

        window_anchors[window] = side;
        warning ("Anchor set");
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
#if HAS_MUTTER45
        var rect = Mtk.Rectangle ();
        window.get_frame_rect (rect);
#else
        Meta.Rectangle rect = window.get_frame_rect ();
#endif

        Meta.Strut strut = {
            rect,
            window_anchors[window]
        };

        window_struts[window] = strut;

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
}
