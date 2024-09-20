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
    private Gtk.Label title_label;

    private int n_windows = 0;

    construct {
        flow_box = new Gtk.FlowBox () {
            homogeneous = true,
            selection_mode = NONE,
            column_spacing = 3,
            row_spacing = 3,
            activate_on_single_click = true
        };

        title_label = new Gtk.Label (null) {
            ellipsize = END
        };

        var box = new Gtk.Box (VERTICAL, 6) {
            margin_top = 12,
            margin_bottom = 12,
            margin_end = 12,
            margin_start = 12
        };
        box.append (flow_box);
        box.append (title_label);

        titlebar = new Gtk.Grid () { visible = false };
        child = box;

        child.realize.connect (connect_to_shell);

        /*
         * Since we hide our surface doesn't get destroyed.
         * But Gala "forgets" about us so every time we present we have to keep above and center again.
         */
        child.map.connect (() => {
            set_keep_above ();
            make_centered ();

            var surface = get_surface ();
            if (surface is Gdk.Toplevel) {
                ((Gdk.Toplevel) surface).inhibit_system_shortcuts (null);
            }

            update_default_size ();
        });

        var key_controller = new Gtk.EventControllerKey () {
            propagation_phase = CAPTURE
        };

        key_controller.key_released.connect ((val) => {
            if (val == Gdk.Key.Alt_L) {
                close_switcher ();
            }
        });

        key_controller.key_pressed.connect ((val, code, modifier_state) => {
            if (val == Gdk.Key.Tab) {
                cycle (SHIFT_MASK in modifier_state);
                return Gdk.EVENT_STOP;
            }

            if (val == Gdk.Key.Right) {
                cycle (false);
                return Gdk.EVENT_STOP;
            }

            if (val == Gdk.Key.Left) {
                cycle (true);
                return Gdk.EVENT_STOP;
            }
        });

        ((Gtk.Widget) this).add_controller (key_controller);

        ShellKeyGrabber.init (this);

        try {
            desktop_integration = Bus.get_proxy_sync (SESSION, "org.pantheon.gala", "/org/pantheon/gala/DesktopInterface");
        } catch (Error e) {
            warning ("Failed to get the desktop integration: %s", e.message);
        }

        flow_box.child_activated.connect (() => close_switcher ());
    }

    public void activate_switcher () {
        flow_box.remove_all ();
        default_width = 1;
        default_height = 1;

        try {
            n_windows = 0;
            foreach (var window in desktop_integration.get_windows ()) {
                if (is_eligible_window (window)) {
                    var icon = new WindowSwitcherIcon (window.uid, (string) window.properties["title"], (string) window.properties["app-id"]);
                    flow_box.append (icon);

                    if (++n_windows == 2) {
                        flow_box.set_focus_child (icon);
                    }
                }
            }
        } catch (Error e) {
            warning ("Failed to get windows: %s", e.message);
        }

        update_title ();
        present ();
    }

    private void update_default_size () {
        Gtk.Requisition natural_size;
        flow_box.get_first_child ().get_preferred_size (null, out natural_size);

        var display_width = Gdk.Display.get_default ().get_monitor_at_surface (get_surface ()).get_geometry ().width - 50;

        var max_children = (int) display_width / (natural_size.width + 3);
        var min_children = (int) Math.fmin (n_windows, max_children);

        flow_box.min_children_per_line = min_children;
        flow_box.max_children_per_line = max_children;

        default_width = 1;
        default_height = 1;
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
        if (backwards) {
            if (!(flow_box.get_focus_child ().get_prev_sibling () is WindowSwitcherIcon)) {
                flow_box.set_focus_child (flow_box.get_last_child ());
            }

            flow_box.child_focus (TAB_BACKWARD);
        } else {
            if (!(flow_box.get_focus_child ().get_next_sibling () is WindowSwitcherIcon)) {
                flow_box.set_focus_child (flow_box.get_first_child ());
            }

            flow_box.child_focus (TAB_FORWARD);
        }

        update_title ();
    }

    private void update_title () {
        var focus_child = flow_box.get_focus_child ();
        if (focus_child != null && focus_child is WindowSwitcherIcon) {
            title_label.label = ((WindowSwitcherIcon) focus_child).title;
        } else {
            title_label.label = null;
        }
    }

    private bool is_eligible_window (DesktopIntegration.Window window) {
        if (!(bool) window.properties["on-active-workspace"]) {
            return false;
        }

        return true;
    }
}
