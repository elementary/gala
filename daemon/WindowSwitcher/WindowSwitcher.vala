
public class Gala.Daemon.WindowSwitcher : Gtk.Window, PantheonWayland.ExtendedBehavior {
    public struct Window {
        string title;
        string icon;
        bool current;
    }

    public Window[] windows { get; set; }

    private Gtk.FlowBox flow_box;

    public WindowSwitcher (Window[] windows) {
        flow_box = new Gtk.FlowBox () {
            homogeneous = true,
            selection_mode = BROWSE
        };

        foreach (var window in windows) {
            var window_icon = new WindowSwitcherIcon (GLib.Icon.new_for_string (window.icon), window.title);

            flow_box.append (window_icon);

            if (window.current) {
                flow_box.select_child (window_icon);
            }
        }

        titlebar = new Gtk.Grid () { visible = false };
        child = flow_box;

        child.realize.connect (() => {
            connect_to_shell ();
            set_keep_above ();
            make_centered ();

            var surface = get_surface ();
            if (surface is Gdk.Toplevel) {
                ((Gdk.Toplevel) surface).inhibit_system_shortcuts (null);
            }
        });

        var key_controller = new Gtk.EventControllerKey () {
            propagation_phase = CAPTURE
        };

        key_controller.key_released.connect ((val) => {
            if (val == Gdk.Key.Alt_L) {
                destroy ();
            }
        });

        key_controller.key_released.connect ((val) => {
            if (val == Gdk.Key.Alt_L) {
                destroy ();
            }
        });

        ((Gtk.Widget) this).add_controller (key_controller);

        present ();
    }
}
