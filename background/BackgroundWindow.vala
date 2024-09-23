
public class Gala.Background.BackgroundWindow : Gtk.Window, PantheonWayland.ExtendedBehavior {
    public int monitor_index { get; construct; }

    private Gtk.Picture picture;

    public BackgroundWindow (int monitor_index) {
        Object (monitor_index: monitor_index);
    }

    construct {
        titlebar = new Gtk.Grid () { visible = false };
        decorated = false;
        can_focus = false;
        child = picture = new Gtk.Picture ();

        child.realize.connect (connect_to_shell);

        map.connect (() => {
            make_background (monitor_index);
            setup_background ();
        });

        present ();
    }

    private void setup_background () {
        var monitor = Gdk.Display.get_default ().get_monitor_at_surface (get_surface ());

        width_request = monitor.geometry.width;
        height_request = monitor.geometry.height;

        var file = File.new_for_path ("/home/leonhard/Pictures/wallpaper.jpg");
        picture.file = file;
    }
}
