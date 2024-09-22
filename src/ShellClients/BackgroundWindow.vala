

public class Gala.BackgroundWindow : Object {
    public Meta.Display display { get; construct; }
    public int monitor_index { get; construct; }

    /**
     * The window that currently provides a background for this monitor.
     */
    private Meta.Window? providing_window;

    public BackgroundWindow (Meta.Display display, int monitor_index) {
        Object (display: display, monitor_index: monitor_index);
    }

    public void update_window (Meta.Window new_window) {
        if (providing_window != null) {
            providing_window.unmanaging.disconnect (on_window_unmanaging);
        }

        providing_window = new_window;

        var monitor_geom = display.get_monitor_geometry (monitor_index);
        providing_window.move_frame (false, monitor_geom.x, monitor_geom.y);

        providing_window.unmanaging.connect (on_window_unmanaging);
    }

    private void on_window_unmanaging () {
        providing_window = null;
    }

    private unowned Clutter.Actor? get_background () {
        return (Clutter.Actor) providing_window.get_compositor_private ();
    }

    public Clutter.Actor get_background_clone () {
        //todo: update on window change (e.g. crash)
        var background_clone = new BackgroundClone ();
        if (providing_window != null) {
            background_clone.background_clone = new Clutter.Clone (get_background ());
        } else {
            Idle.add (() => {
                if (providing_window != null) {
                    background_clone.background_clone = new Clutter.Clone (get_background ());
                    return Source.REMOVE;
                }

                return Source.CONTINUE;
            });
        }
        return background_clone;
    }

    public class BackgroundClone : Clutter.Actor {
        public Clutter.Clone background_clone {
            set {
                remove_all_children ();
                add_child (value);
            }
        }
    }
}
