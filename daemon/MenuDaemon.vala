//
//  Copyright 2018-2020 elementary, Inc. (https://elementary.io)
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Gala {
    private const string DBUS_NAME = "org.pantheon.gala";
    private const string DBUS_OBJECT_PATH = "/org/pantheon/gala";

    private const string DAEMON_DBUS_NAME = "org.pantheon.gala.daemon";
    private const string DAEMON_DBUS_OBJECT_PATH = "/org/pantheon/gala/daemon";

    [DBus (name = "org.pantheon.gala")]
    public interface WMDBus : GLib.Object {
        public abstract void perform_action (Gala.ActionType type) throws DBusError, IOError;
    }

    [DBus (name = "org.pantheon.gala.daemon")]
    public class MenuDaemon : Object {
        // Window Menu
        private Granite.AccelLabel always_on_top_accellabel;
        private Granite.AccelLabel close_accellabel;
        private Granite.AccelLabel hide_accellabel;
        private Granite.AccelLabel move_accellabel;
        private Granite.AccelLabel move_left_accellabel;
        private Granite.AccelLabel move_right_accellabel;
        private Granite.AccelLabel on_visible_workspace_accellabel;
        private Granite.AccelLabel resize_accellabel;
        private Granite.AccelLabel screenshot_accellabel;
        private Gtk.Menu? window_menu = null;
        private Gtk.MenuItem hide;
        private Gtk.MenuItem maximize;
        private Gtk.MenuItem move;
        private Gtk.MenuItem resize;
        private Gtk.CheckMenuItem always_on_top;
        private Gtk.CheckMenuItem on_visible_workspace;
        private Gtk.MenuItem move_left;
        private Gtk.MenuItem move_right;
        private Gtk.MenuItem close;
        private Gtk.MenuItem screenshot;

        // Desktop Menu
        private Gtk.Menu? desktop_menu = null;

        private WMDBus? wm_proxy = null;

        private ulong always_on_top_sid = 0U;
        private ulong on_visible_workspace_sid = 0U;

        private static GLib.Settings keybind_settings;
        private static GLib.Settings gala_keybind_settings;

        static construct {
            keybind_settings = new GLib.Settings ("org.gnome.desktop.wm.keybindings");
            gala_keybind_settings = new GLib.Settings ("org.pantheon.desktop.gala.keybindings");
        }

        [DBus (visible = false)]
        public void setup_dbus () {
            var flags = BusNameOwnerFlags.ALLOW_REPLACEMENT | BusNameOwnerFlags.REPLACE;
            Bus.own_name (BusType.SESSION, DAEMON_DBUS_NAME, flags, on_bus_acquired, () => {}, null);

            Bus.watch_name (BusType.SESSION, DBUS_NAME, BusNameWatcherFlags.NONE, gala_appeared, lost_gala);
        }

        private void on_gala_get (GLib.Object? o, GLib.AsyncResult? res) {
            try {
                wm_proxy = Bus.get_proxy.end (res);
            } catch (Error e) {
                warning ("Failed to get Gala proxy: %s", e.message);
            }
        }

        private void lost_gala () {
            wm_proxy = null;
        }

        private void gala_appeared () {
            if (wm_proxy == null) {
                Bus.get_proxy.begin<WMDBus> (BusType.SESSION, DBUS_NAME, DBUS_OBJECT_PATH, 0, null, on_gala_get);
            }
        }

        private void on_bus_acquired (DBusConnection conn) {
            try {
                conn.register_object (DAEMON_DBUS_OBJECT_PATH, this);
            } catch (Error e) {
                stderr.printf ("Error registering MenuDaemon: %s\n", e.message);
            }
        }

        private void perform_action (Gala.ActionType type) {
            if (wm_proxy != null) {
                try {
                    wm_proxy.perform_action (type);
                } catch (Error e) {
                    warning ("Failed to perform Gala action over DBus: %s", e.message);
                }
            }
        }

        private void init_window_menu () {
            hide_accellabel = new Granite.AccelLabel (_("Hide"));

            hide = new Gtk.MenuItem ();
            hide.add (hide_accellabel);
            hide.activate.connect (() => {
                perform_action (Gala.ActionType.HIDE_CURRENT);
            });

            maximize = new Gtk.MenuItem ();
            maximize.activate.connect (() => {
                perform_action (Gala.ActionType.MAXIMIZE_CURRENT);
            });

            move_accellabel = new Granite.AccelLabel (_("Move"));

            move = new Gtk.MenuItem ();
            move.add (move_accellabel);
            move.activate.connect (() => {
                perform_action (Gala.ActionType.START_MOVE_CURRENT);
            });

            resize_accellabel = new Granite.AccelLabel (_("Resize"));

            resize = new Gtk.MenuItem ();
            resize.add (resize_accellabel);
            resize.activate.connect (() => {
                perform_action (Gala.ActionType.START_RESIZE_CURRENT);
            });

            always_on_top_accellabel = new Granite.AccelLabel (_("Always on Top"));

            always_on_top = new Gtk.CheckMenuItem ();
            always_on_top.add (always_on_top_accellabel);
            always_on_top_sid = always_on_top.activate.connect (() => {
                perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_TOP_CURRENT);
            });

            on_visible_workspace_accellabel = new Granite.AccelLabel (_("Always on Visible Workspace"));

            on_visible_workspace = new Gtk.CheckMenuItem ();
            on_visible_workspace.add (on_visible_workspace_accellabel);
            on_visible_workspace_sid = on_visible_workspace.activate.connect (() => {
                perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_VISIBLE_WORKSPACE_CURRENT);
            });

            move_left_accellabel = new Granite.AccelLabel (_("Move to Workspace Left"));

            move_left = new Gtk.MenuItem ();
            move_left.add (move_left_accellabel);
            move_left.activate.connect (() => {
                perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_LEFT);
            });

            move_right_accellabel = new Granite.AccelLabel (_("Move to Workspace Right"));

            move_right = new Gtk.MenuItem ();
            move_right.add (move_right_accellabel);
            move_right.activate.connect (() => {
                perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_RIGHT);
            });

            screenshot_accellabel = new Granite.AccelLabel (_("Take Screenshot"));

            screenshot = new Gtk.MenuItem ();
            screenshot.add (screenshot_accellabel);
            screenshot.activate.connect (() => {
                perform_action (Gala.ActionType.SCREENSHOT_CURRENT);
            });

            close_accellabel = new Granite.AccelLabel (_("Close"));

            close = new Gtk.MenuItem ();
            close.add (close_accellabel);
            close.activate.connect (() => {
                perform_action (Gala.ActionType.CLOSE_CURRENT);
            });

            window_menu = new Gtk.Menu ();
            window_menu.append (screenshot);
            window_menu.append (new Gtk.SeparatorMenuItem ());
            window_menu.append (always_on_top);
            window_menu.append (on_visible_workspace);
            window_menu.append (move_left);
            window_menu.append (move_right);
            window_menu.append (new Gtk.SeparatorMenuItem ());
            window_menu.append (move);
            window_menu.append (resize);
            window_menu.append (maximize);
            window_menu.append (new Gtk.SeparatorMenuItem ());
            window_menu.append (hide);
            window_menu.append (close);
            window_menu.show_all ();
        }

        public void show_window_menu (Gala.WindowFlags flags, int x, int y) throws DBusError, IOError {
            if (window_menu == null) {
                init_window_menu ();
            }

            hide.visible = Gala.WindowFlags.CAN_HIDE in flags;
            if (hide.visible) {
                hide_accellabel.accel_string = keybind_settings.get_strv ("minimize")[0];
            }

            maximize.visible = Gala.WindowFlags.CAN_MAXIMIZE in flags;
            if (maximize.visible) {
                unowned string maximize_label;
                if (Gala.WindowFlags.IS_MAXIMIZED in flags) {
                    maximize_label = (Gala.WindowFlags.IS_TILED in flags) ? _("Untile") : _("Unmaximize");
                } else {
                    maximize_label = _("Maximize");
                }

                maximize.get_child ().destroy ();
                maximize.add (
                    new Granite.AccelLabel (
                        maximize_label,
                        keybind_settings.get_strv ("toggle-maximized")[0]
                    )
                );
            }


            move.visible = Gala.WindowFlags.ALLOWS_MOVE in flags;
            if (move.visible) {
                move_accellabel.accel_string = keybind_settings.get_strv ("begin-move")[0];
            }

            resize.visible = Gala.WindowFlags.ALLOWS_RESIZE in flags;
            if (resize.visible) {
                resize_accellabel.accel_string = keybind_settings.get_strv ("begin-resize")[0];
            }

            // Setting active causes signal fires on activate so
            // we temporarily block those signals from emissions
            SignalHandler.block (always_on_top, always_on_top_sid);
            SignalHandler.block (on_visible_workspace, on_visible_workspace_sid);

            always_on_top.active = Gala.WindowFlags.ALWAYS_ON_TOP in flags;
            always_on_top_accellabel.accel_string = keybind_settings.get_strv ("always-on-top")[0];

            on_visible_workspace.active = Gala.WindowFlags.ON_ALL_WORKSPACES in flags;
            on_visible_workspace_accellabel.accel_string = keybind_settings.get_strv ("toggle-on-all-workspaces")[0];

            SignalHandler.unblock (always_on_top, always_on_top_sid);
            SignalHandler.unblock (on_visible_workspace, on_visible_workspace_sid);

            move_right.sensitive = !on_visible_workspace.active;
            if (move_right.sensitive) {
                move_right_accellabel.accel_string = keybind_settings.get_strv ("move-to-workspace-right")[0];
            }

            move_left.sensitive = !on_visible_workspace.active;
            if (move_left.sensitive) {
                move_left_accellabel.accel_string = keybind_settings.get_strv ("move-to-workspace-left")[0];
            }

            screenshot_accellabel.accel_string = gala_keybind_settings.get_strv ("window-screenshot")[0];

            close.visible = Gala.WindowFlags.CAN_CLOSE in flags;
            if (close.visible) {
                close_accellabel.accel_string = keybind_settings.get_strv ("close")[0];
            }

            // `opened` is used as workaround for https://github.com/elementary/gala/issues/1387
            var opened = false;
            Idle.add (() => {
                window_menu.popup (null, null, (m, ref px, ref py, out push_in) => {
                    var scale = m.scale_factor;
                    px = x / scale;
                    // Move the menu 1 pixel outside of the pointer or else it closes instantly
                    // on the mouse up event
                    py = (y / scale) + 1;
                    push_in = true;
                    opened = true;
                }, Gdk.BUTTON_SECONDARY, Gdk.CURRENT_TIME);

                return opened ? Source.REMOVE : Source.CONTINUE;
            });
        }

        public void show_desktop_menu (int x, int y) throws DBusError, IOError {
            if (desktop_menu == null) {
                var change_wallpaper = new Gtk.MenuItem.with_label (_("Change Wallpaper…"));
                change_wallpaper.activate.connect (() => {
                    try {
                        AppInfo.launch_default_for_uri ("settings://desktop/appearance/wallpaper", null);
                    } catch (Error e) {
                        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                            "Failed to Open Wallpaper Settings",
                            "Unable to open System Settings. A handler for the `settings://` URI scheme must be installed.",
                            "dialog-error",
                            Gtk.ButtonsType.CLOSE
                        );
                        message_dialog.show_error_details (e.message);
                        message_dialog.run ();
                        message_dialog.destroy ();
                    }
                });

                var display_settings = new Gtk.MenuItem.with_label (_("Display Settings…"));
                display_settings.activate.connect (() => {
                    try {
                        AppInfo.launch_default_for_uri ("settings://display", null);
                    } catch (Error e) {
                        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                            "Failed to Open Display Settings",
                            "Unable to open System Settings. A handler for the `settings://` URI scheme must be installed.",
                            "dialog-warning",
                            Gtk.ButtonsType.CLOSE
                        );
                        message_dialog.show_error_details (e.message);
                        message_dialog.run ();
                        message_dialog.destroy ();
                    }
                });

                var system_settings = new Gtk.MenuItem.with_label (_("System Settings…"));
                system_settings.activate.connect (() => {
                    try {
                        AppInfo.launch_default_for_uri ("settings://", null);
                    } catch (Error e) {
                        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                            "Failed to Open System Settings",
                            "Unable to open System Settings. A handler for the `settings://` URI scheme must be installed.",
                            "dialog-warning",
                            Gtk.ButtonsType.CLOSE
                        );
                        message_dialog.show_error_details (e.message);
                        message_dialog.run ();
                        message_dialog.destroy ();
                    }
                });

                desktop_menu = new Gtk.Menu ();
                desktop_menu.append (change_wallpaper);
                desktop_menu.append (display_settings);
                desktop_menu.append (new Gtk.SeparatorMenuItem ());
                desktop_menu.append (system_settings);
                desktop_menu.show_all ();
            }

            desktop_menu.popup (null, null, (m, ref px, ref py, out push_in) => {
                var scale = m.scale_factor;
                px = x / scale;
                // Move the menu 1 pixel outside of the pointer or else it closes instantly
                // on the mouse up event
                py = (y / scale) + 1;
                push_in = false;
            }, Gdk.BUTTON_SECONDARY, Gdk.CURRENT_TIME);
        }
    }
}
