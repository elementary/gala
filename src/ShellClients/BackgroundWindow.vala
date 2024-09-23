

public class Gala.BackgroundWindow : Object {
    public Meta.Display display { get; construct; }
    public int monitor_index { get; construct; }

    /**
     * The window that currently provides a background for this monitor.
     */
    public Meta.Window? providing_window { get; private set; }

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

    public Clutter.Actor get_background_clone () {
        return new BackgroundClone (this);
    }

    private class BackgroundClone : Clutter.Actor {
        public BackgroundWindow background_window { get; construct; }

        public BackgroundClone (BackgroundWindow background_window) {
            Object (background_window: background_window);
        }

        construct {
            update_clone ();
            background_window.notify["providing-window"].connect (update_clone);
        }

        private void update_clone () {
            remove_all_children ();

            if (background_window.providing_window != null) {
                add_child (new Clutter.Clone ((Clutter.Actor) background_window.providing_window.get_compositor_private ()));
            }
        }
    }
}
