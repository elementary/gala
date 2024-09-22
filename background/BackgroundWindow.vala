
public class Gala.Background.BackgroundWindow : Gtk.Window, PantheonWayland.ExtendedBehavior {
    private Gtk.Picture picture;

    construct {
        titlebar = new Gtk.Grid () { visible = false };
        decorated = false;
        can_focus = false;
        child = picture = new Gtk.Picture ();

        child.realize.connect (connect_to_shell);

        map.connect (() => {
            make_background (0);
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
