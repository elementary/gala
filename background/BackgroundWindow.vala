/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.Background.BackgroundWindow : Gtk.Window, PantheonWayland.ExtendedBehavior {
    private const string BG_MENU_ACTION_GROUP_PREFIX = "background-menu";
    private const string BG_MENU_ACTION_PREFIX = BG_MENU_ACTION_GROUP_PREFIX + ".";

    public int monitor_index { get; construct; }

    private Gtk.PopoverMenu background_menu;
    private Gtk.Overlay overlay;

    public BackgroundWindow (int monitor_index) {
        Object (monitor_index: monitor_index);
    }

    construct {
        var background_menu_top_section = new Menu ();
        background_menu_top_section.append (
            _("Change Wallpaper…"),
            Action.print_detailed_name (BG_MENU_ACTION_PREFIX + "launch-uri", "settings://desktop/appearance/wallpaper")
        );
        background_menu_top_section.append (
            _("Display Settings…"),
            Action.print_detailed_name (BG_MENU_ACTION_PREFIX + "launch-uri", "settings://display")
        );

        var background_menu_bottom_section = new Menu ();
        background_menu_bottom_section.append (
            _("System Settings…"),
            Action.print_detailed_name (BG_MENU_ACTION_PREFIX + "launch-uri", "settings://")
        );

        var background_menu_model = new Menu ();
        background_menu_model.append_section (null, background_menu_top_section);
        background_menu_model.append_section (null, background_menu_bottom_section);

        background_menu = new Gtk.PopoverMenu.from_model (background_menu_model) {
            halign = START,
            position = BOTTOM,
            has_arrow = false
        };
        background_menu.set_parent (this);

        var launch_action = new SimpleAction ("launch-uri", VariantType.STRING);
        launch_action.activate.connect (action_launch);

        var action_group = new SimpleActionGroup ();
        action_group.add_action (launch_action);

        background_menu.insert_action_group (BG_MENU_ACTION_GROUP_PREFIX, action_group);

        overlay = new Gtk.Overlay ();

        titlebar = new Gtk.Grid () { visible = false };
        decorated = false;
        can_focus = false;
        child = overlay;

        child.realize.connect (() => {
            connect_to_shell ();
            get_surface ().notify["scale"].connect (update_size);
        });

        map.connect (() => {
            if (get_surface () is Gdk.Wayland.Surface) {
                make_background (monitor_index);
            } else {
                make_background_x11 ();
            }

            update_size ();
        });

        var gesture = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        overlay.add_controller (gesture);

        gesture.pressed.connect ((n_press, x, y) => {
            var rect = Gdk.Rectangle () {
                x = (int) x,
                y = (int) y
            };

            background_menu.pointing_to = rect;
            background_menu.popup ();
        });


        present ();
    }

    private void update_size () {
        var monitor = Gdk.Display.get_default ().get_monitor_at_surface (get_surface ());
        var geom = monitor.get_geometry ();

        /* First convert into physical size of the monitor */
        geom.width = (int) (geom.width * monitor.scale);
        geom.height = (int) (geom.height * monitor.scale);

        /* Then convert into logical size as per surface scale. We do this because
         * for some reason surface scale doesn't have to equal monitor scale */
        default_width = width_request = (int) (geom.width / get_surface ().scale);
        default_height = height_request = (int) (geom.height / get_surface ().scale);
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

    private void make_background_x11 () {
        unowned var xdisplay = ((Gdk.X11.Display) display).get_xdisplay ();

        unowned var xwindow = ((Gdk.X11.Surface) get_surface ()).get_xid ();

        var atom = xdisplay.intern_atom ("_NET_WM_WINDOW_TYPE", false);
        var dock_atom = xdisplay.intern_atom ("_NET_WM_WINDOW_TYPE_DESKTOP", false);

        // (X.Atom) 4 is XA_ATOM
        // 32 is format
        // 0 means replace
        xdisplay.change_property (xwindow, atom, (X.Atom) 4, 32, 0, (uchar[]) dock_atom, 1);

        var mutter_prop = xdisplay.intern_atom ("_MUTTER_HINTS", false);

        var mutter_prop_value = "monitor-index=%d".printf (monitor_index);

        xdisplay.change_property (xwindow, mutter_prop, X.XA_STRING, 8, 0, (uchar[]) mutter_prop_value, mutter_prop_value.length);
    }

    private static void action_launch (SimpleAction action, Variant? variant) {
        try {
            AppInfo.launch_default_for_uri (variant.get_string (), null);
        } catch (Error e) {
            var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Failed to open System Settings"),
                _("A handler for the “settings://” URI scheme must be installed."),
                "dialog-error",
                Gtk.ButtonsType.CLOSE
            );
            message_dialog.show_error_details (e.message);
            message_dialog.present ();
            message_dialog.response.connect (message_dialog.destroy);
        }
    }
}
