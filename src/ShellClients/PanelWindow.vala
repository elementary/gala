public class Gala.PanelWindow : Object {
    public enum HideMode {
        NEVER,
        MAXIMIZED_FOCUS_WINDOW,
        OVERLAPPING_FOCUS_WINDOW,
        OVERLAPPING_WINDOW,
        ALWAYS
    }

    private static GLib.HashTable<Meta.Window, Meta.Strut?> window_struts = new GLib.HashTable<Meta.Window, Meta.Strut?> (null, null);

    public Meta.Display display { get; construct; }
    public Meta.Window window { get; construct; }

    public Meta.Rectangle? static_region { get; private set; }
    public bool hidden { get; private set; default = false; }

    private Meta.Side anchor;
    private HideTracker hide_tracker;

    private Barrier? barrier;

    public PanelWindow (Meta.Display display, Meta.Window window, Meta.Side anchor) {
        Object (display: display, window: window);

        this.anchor = anchor;
    }

    construct {
        window.size_changed.connect (position_window);

        hide_tracker = new HideTracker (display, this, NEVER);

        hide_tracker.notify["should-hide"].connect (() => {
            if (hide_tracker.should_hide) {
                hide ();
            } else {
                show ();
            }
        });

        window.unmanaged.connect (() => {
            if (window_struts.remove (window)) {
                update_struts ();
            }
        });
    }

    public void update_anchor (Meta.Side anchor) {
        this.anchor = anchor;

        position_window ();
        set_hide_mode (hide_tracker.hide_mode); // Resetup barriers etc.
    }

    private void position_window () {
        if (hidden) {
            return;
        }

        var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());
        var window_rect = window.get_frame_rect ();

        switch (anchor) {
            case TOP:
                position_window_top (monitor_geom, window_rect);
                break;

            case BOTTOM:
                position_window_bottom (monitor_geom, window_rect);
                break;

            default:
                warning ("Side not supported yet");
                break;
        }
    }

    private void position_window_top (Meta.Rectangle monitor_geom, Meta.Rectangle window_rect) {
        var x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;

        move_window_idle (x, monitor_geom.y);
    }

    private void position_window_bottom (Meta.Rectangle monitor_geom, Meta.Rectangle window_rect) {
        var x = monitor_geom.x + (monitor_geom.width - window_rect.width) / 2;
        var y = monitor_geom.y + monitor_geom.height - window_rect.height;

        move_window_idle (x, y);
    }

    private void move_window_idle (int x, int y) {
        Idle.add (() => {
            window.move_frame (true, x, y);
            static_region = window.get_buffer_rect ();
            return Source.REMOVE;
        });
    }

    public void set_hide_mode (HideMode hide_mode) {
        hide_tracker.hide_mode = hide_mode;

        if (hide_mode != NEVER) {
            unmake_exclusive ();
            setup_barrier ();
        } else {
            make_exclusive ();
            barrier = null; //TODO: check whether that actually disables it
        }
    }

    private void make_exclusive () {
        window.size_changed.connect (update_strut);
        update_strut ();
    }

    private void update_strut () {
        var rect = window.get_frame_rect ();

        Meta.Strut strut = {
            rect,
            anchor
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

    private void unmake_exclusive () {
        if (window in window_struts) {
            window.size_changed.disconnect (update_strut);
            window_struts.remove (window);
            update_struts ();
        }
    }

    private void setup_barrier () {
        switch (anchor) {
            case BOTTOM:
                setup_barrier_bottom ();
                break;

            default:
                warning ("Barrier side not supported yet");
                break;
        }
    }

    private void setup_barrier_bottom () {
        var monitor_geom = display.get_monitor_geometry (display.get_primary_monitor ());

        barrier = new Barrier (
            display,
            monitor_geom.x,
            monitor_geom.y + monitor_geom.height,
            monitor_geom.x + monitor_geom.width,
            monitor_geom.y + monitor_geom.height,
            NEGATIVE_Y,
            0,
            0,
            int.MAX,
            int.MAX
        );

        barrier.trigger.connect (() => {
            show ();
        });
    }

    private void hide () {
        hidden = true;
        ((Meta.WindowActor)window.get_compositor_private ()).hide ();
    }

    private void show () {
        hidden = false;
        ((Meta.WindowActor)window.get_compositor_private ()).show ();
    }
}