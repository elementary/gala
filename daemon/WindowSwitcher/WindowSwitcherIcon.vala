
public class Gala.Daemon.WindowSwitcherIcon : Gtk.FlowBoxChild {
    public GLib.Icon icon { get; construct; }
    public string title { get; construct; }

    public WindowSwitcherIcon (GLib.Icon icon, string title) {
        Object (
            icon: icon,
            title: title
        );
    }

    construct {
        var image = new Gtk.Image.from_gicon (icon) {
            pixel_size = 64
        };

        child = image;
    }
}
