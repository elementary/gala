[DBus (name="org.pantheon.gala.DesktopIntegration")]
public interface DesktopIntegration : Object {
    public struct Window {
        uint64 uid;
        GLib.HashTable<string, Variant> properties;
    }

    public abstract Window[] get_windows () throws IOError, DBusError;
    public abstract void focus_window (uint64 uid) throws GLib.DBusError, GLib.IOError;
    public abstract int get_active_workspace () throws GLib.DBusError, GLib.IOError;
}

[DBus (name="io.elementary.WindowSwitcher")]
public class Gala.Daemon.WindowSwitcher : Gtk.Window {
    private const double GESTURE_STEP = 0.2;

    private DesktopIntegration? desktop_integration;

    private Gtk.FlowBox flow_box;
    private Gtk.Label title_label;

    private int n_windows = 0;

    private bool opened = false;
    private bool only_current = false;

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

        //  child.realize.connect (connect_to_shell);

        /*
         * Because we hide, our surface doesn't get destroyed.
         * But Gala "forgets" about us so every time we present we have to keep above and center again.
         */
        //  child.map.connect (() => {
        //      //  set_keep_above ();
        //      //  make_centered ();

        //      var surface = get_surface ();
        //      if (surface is Gdk.Toplevel) {
        //          ((Gdk.Toplevel) surface).inhibit_system_shortcuts (null);
        //      }

        //      update_default_size ();
        //  });

        var key_controller = new Gtk.EventControllerKey () {
            propagation_phase = CAPTURE
        };

        key_controller.key_pressed.connect ((val, code, modifier_state) => {
            if (val == Gdk.Key.Right) {
                cycle (only_current, false);
                return Gdk.EVENT_STOP;
            }

            if (val == Gdk.Key.Left) {
                cycle (only_current, true);
                return Gdk.EVENT_STOP;
            }

            return Gdk.EVENT_PROPAGATE;
        });

        ((Gtk.Widget) this).add_controller (key_controller);

        try {
            desktop_integration = Bus.get_proxy_sync (SESSION, "org.pantheon.gala", "/org/pantheon/gala/DesktopInterface");
        } catch (Error e) {
            warning ("Failed to get the desktop integration: %s", e.message);
        }

        flow_box.child_activated.connect (() => close ());
    }

    public void open () throws DBusError, IOError {
        opened = true;
        this.only_current = false;

        n_windows = 0;

        flow_box.remove_all ();

        try {
            var windows = desktop_integration.get_windows ();
            warning ("Got %d windows", windows.length);
            var current_app_id = only_current ? get_current_app_id (windows) : null;
            foreach (var window in windows) {
                if (is_eligible_window (window, current_app_id)) {
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

        if (n_windows == 0) {
            opened = false;
            //  get_surface ().beep ();
            return;
        }

        if (n_windows == 1) {
            flow_box.set_focus_child (flow_box.get_first_child ());
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

    public new void close () throws DBusError, IOError {
        hide ();

        var icon = (WindowSwitcherIcon) flow_box.get_focus_child ();

        try {
            desktop_integration.focus_window (icon.uid);
        } catch (Error e) {
            warning ("Failed to focus window");
        }

        opened = false;
    }

    public void set_progress (double progress) throws DBusError, IOError {
        var new_index = ((int) Math.round (progress / GESTURE_STEP)) % n_windows;

        for (var child = flow_box.get_first_child (); child != null; child = child.get_next_sibling ()) {
            if (new_index == 0) {
                flow_box.set_focus_child (child);
                break;
            }

            new_index--;
        }

        update_title ();
    }

    private void cycle (bool only_current, bool backwards) {
        //  return;
        //  if (!active) {
        //      activate_switcher (only_current);
        //      return;
        //  }

        //  if (this.only_current != only_current) {
        //      //todo: gdk beep?
        //      return;
        //  }

        //  if (backwards) {
        //      if (!(flow_box.get_focus_child ().get_prev_sibling () is WindowSwitcherIcon)) {
        //          flow_box.set_focus_child (flow_box.get_last_child ());
        //      }

        //      flow_box.child_focus (TAB_BACKWARD);
        //  } else {
        //      if (!(flow_box.get_focus_child ().get_next_sibling () is WindowSwitcherIcon)) {
        //          flow_box.set_focus_child (flow_box.get_first_child ());
        //      }

        //      flow_box.child_focus (TAB_FORWARD);
        //  }
    }

    private void update_title () {
        var focus_child = flow_box.get_focus_child ();
        if (focus_child != null && focus_child is WindowSwitcherIcon) {
            title_label.label = ((WindowSwitcherIcon) focus_child).title;
        } else {
            title_label.label = null;
        }
    }

    private bool is_eligible_window (DesktopIntegration.Window window, string? current_app_id) {
        if (window.properties["workspace-index"].get_int32 () != desktop_integration.get_active_workspace ()) {
            return false;
        }

        if (current_app_id != null && (string) window.properties["app-id"] != current_app_id) {
            return false;
        }

        return true;
    }

    private string? get_current_app_id (DesktopIntegration.Window[] windows) {
        foreach (var window in windows) {
            if ((bool) window.properties["has-focus"]) {
                return (string) window.properties["app-id"];
            }
        }

        return null;
    }
}
