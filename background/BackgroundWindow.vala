
public class Gala.Background.BackgroundWindow : Gtk.Window, PantheonWayland.ExtendedBehavior {
    public int monitor_index { get; construct; }

    private Gtk.Overlay overlay;

    public BackgroundWindow (int monitor_index) {
        Object (monitor_index: monitor_index);
    }

    construct {
        overlay = new Gtk.Overlay ();

        titlebar = new Gtk.Grid () { visible = false };
        decorated = false;
        can_focus = false;
        child = overlay;

        child.realize.connect (connect_to_shell);

        map.connect (() => {
            make_background (monitor_index);
            setup_size ();
        });

        present ();
    }

    private void setup_size () {
        var monitor = Gdk.Display.get_default ().get_monitor_at_surface (get_surface ());

        width_request = monitor.geometry.width;
        height_request = monitor.geometry.height;
    }

    public void set_background (Gdk.Paintable paintable) {
        var old_picture = overlay.child;

        var new_picture = new Gtk.Picture () {
            content_fit = COVER,
            paintable = paintable
        };
        overlay.child = new_picture;

        if (old_picture == null) {
            return;
        }

        overlay.add_overlay (old_picture);

        var animation = new Adw.TimedAnimation (old_picture, 1.0, 0.0, 1000, new Adw.PropertyAnimationTarget (old_picture, "opacity"));
        animation.done.connect ((animation) => {
            overlay.remove_overlay (animation.widget);
        });
        animation.play ();
    }
}
