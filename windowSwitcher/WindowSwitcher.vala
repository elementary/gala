[DBus (name="org.pantheon.gala.DesktopIntegration")]
public interface DesktopIntegration : Object {
    public struct Window {
        uint64 uid;
        GLib.HashTable<unowned string, Variant> properties;
    }

    public abstract Window[] get_windows () throws IOError, DBusError;
    public abstract void focus_window (uint64 uid) throws GLib.DBusError, GLib.IOError;
}

public class Gala.WindowSwitcher.WindowSwitcher : Gtk.Window, PantheonWayland.ExtendedBehavior {
    private DesktopIntegration? desktop_integration;
    private Gtk.FlowBox flow_box;

    construct {
        flow_box = new Gtk.FlowBox () {
            homogeneous = true,
            selection_mode = BROWSE,
            min_children_per_line = 10
        };

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
                close_switcher ();
            }
        });

        key_controller.key_pressed.connect ((val) => {
            if (val == Gdk.Key.Tab) {
                cycle (false);
            }
        });

        ((Gtk.Widget) this).add_controller (key_controller);

        ShellKeyGrabber.init (this);

        try {
            desktop_integration = Bus.get_proxy_sync (SESSION, "org.pantheon.gala", "/org/pantheon/gala/DesktopInterface");
        } catch (Error e) {
            warning ("Failed to get the desktop integration: %s", e.message);
        }
    }

    public void activate_switcher () {
        flow_box.remove_all ();
        default_width = 1;
        default_height = 1;

        try {
            int i = 0;
            foreach (var window in desktop_integration.get_windows ()) {
                if (is_eligible_window (window)) {
                    var icon = new WindowSwitcherIcon (window.uid, (string) window.properties["title"], (string) window.properties["app-id"]);
                    flow_box.append (icon);

                    if (++i == 2) {
                        flow_box.set_focus_child (icon);
                    }
                }
            }
        } catch (Error e) {
            warning ("Failed to get windows: %s", e.message);
        }

        present ();
    }

    public void close_switcher () {
        hide ();

        var icon = (WindowSwitcherIcon) flow_box.get_focus_child ();

        try {
            desktop_integration.focus_window (icon.uid);
        } catch (Error e) {
            warning ("Failed to focus window");
        }
    }

    private void cycle (bool backwards) {
        if (!(flow_box.get_focus_child ().get_next_sibling () is WindowSwitcherIcon)) {
            flow_box.set_focus_child (flow_box.get_first_child ());
        }

        flow_box.child_focus (TAB_FORWARD);
    }

    private bool is_eligible_window (DesktopIntegration.Window window) {
        return true;
    }
}
