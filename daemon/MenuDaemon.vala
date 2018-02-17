//
//  Copyright (c) 2018 elementary LLC. (https://elementary.io)
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

namespace GalaDaemon {
	[DBus (name = "org.pantheon.gala")]
	public interface GalaInterface : GLib.Object
	{
		public abstract void perform_action (Gala.ActionType type);
	}

	[DBus (name = "io.elementary.gala.daemon")]
	public class MenuDaemon : Object
	{
		private const string MENU_DBUS_NAME = "io.elementary.gala.daemon";
		private const string MENU_DBUS_OBJECT_PATH = "/io/elementary/gala/daemon";

		private const string GALA_DBUS_NAME = "org.pantheon.gala";
		private const string GALA_DBUS_OBJECT_PATH = "/org/pantheon/gala";

		private Gtk.Menu? window_menu = null;
		private Gtk.MenuItem minimize;
		private Gtk.MenuItem maximize;
		private Gtk.MenuItem move;
		private Gtk.MenuItem resize;
		private Gtk.CheckMenuItem always_on_top;
		private Gtk.CheckMenuItem on_visible_workspace;
		private Gtk.MenuItem move_left;
		private Gtk.MenuItem move_right;
		private Gtk.MenuItem close;

		private GalaInterface? gala_proxy = null;

		[DBus (visible = false)]
		public void setup_dbus ()
		{
			var flags = BusNameOwnerFlags.ALLOW_REPLACEMENT | BusNameOwnerFlags.REPLACE;
			Bus.own_name (BusType.SESSION, MENU_DBUS_NAME, flags, on_bus_acquired, () => {}, null);

			Bus.watch_name (BusType.SESSION, GALA_DBUS_NAME, BusNameWatcherFlags.NONE, has_gala, lost_gala);
		}

		void on_gala_get (GLib.Object? o, GLib.AsyncResult? res)
		{
			try {
				gala_proxy = Bus.get_proxy.end (res);
			} catch (Error e) {
				warning ("Failed to get Gala proxy: %s", e.message);
			}
		}

		void lost_gala ()
		{
			gala_proxy = null;
		}

		void has_gala ()
		{
			if (gala_proxy == null) {
				Bus.get_proxy.begin<GalaInterface> (BusType.SESSION,
													GALA_DBUS_NAME,
													GALA_DBUS_OBJECT_PATH,
													0, null, on_gala_get);
			}
		}

		private void on_bus_acquired (DBusConnection conn)
		{
			try {
				conn.register_object (MENU_DBUS_OBJECT_PATH, this);
			} catch (Error e) {
				stderr.printf ("Error registering MenuDaemon: %s\n", e.message);
			}
		}

		[DBus (visible = false)]
		private void init_window_menu ()
		{
			window_menu = new Gtk.Menu ();

			minimize = new Gtk.MenuItem.with_label (_("Minimize"));
			minimize.activate.connect (() => {
				if (gala_proxy != null) {
					gala_proxy.perform_action (Gala.ActionType.MINIMIZE_CURRENT);
				}
			});
			window_menu.append (minimize);

			maximize = new Gtk.MenuItem.with_label ("");
			maximize.activate.connect (() => {
				if (gala_proxy != null) {
					gala_proxy.perform_action (Gala.ActionType.MAXIMIZE_CURRENT);
				}
			});
			window_menu.append (maximize);

			move = new Gtk.MenuItem.with_label (_("Move"));
			move.activate.connect (() => {
				if (gala_proxy != null) {
					gala_proxy.perform_action (Gala.ActionType.START_MOVE_CURRENT);
				}
			});
			window_menu.append (move);

			resize = new Gtk.MenuItem.with_label (_("Resize"));
			resize.activate.connect (() => {
				if (gala_proxy != null) {
					gala_proxy.perform_action (Gala.ActionType.START_RESIZE_CURRENT);
				}
			});
			window_menu.append (resize);

			always_on_top = new Gtk.CheckMenuItem.with_label (_("Always on Top"));
			always_on_top.activate.connect (() => {
				if (gala_proxy != null) {
					gala_proxy.perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_TOP_CURRENT);
				}
			});
			window_menu.append (always_on_top);

			on_visible_workspace = new Gtk.CheckMenuItem.with_label (_("Always on Visible Workspace"));
			on_visible_workspace.activate.connect (() => {
				if (gala_proxy != null) {
					gala_proxy.perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_VISIBLE_WORKSPACE_CURRENT);
				}
			});
			window_menu.append (on_visible_workspace);

			move_left = new Gtk.MenuItem.with_label (_("Move to Workspace Left"));
			move_left.activate.connect (() => {
				if (gala_proxy != null) {
					gala_proxy.perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_LEFT);
				}
			});
			window_menu.append (move_left);

			move_right = new Gtk.MenuItem.with_label (_("Move to Workspace Right"));
			move_right.activate.connect (() => {
				if (gala_proxy != null) {
					gala_proxy.perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_RIGHT);
				}
			});
			window_menu.append (move_right);

			close = new Gtk.MenuItem.with_label (_("Close"));
			close.activate.connect (() => {
				if (gala_proxy != null) {
					gala_proxy.perform_action (Gala.ActionType.CLOSE_CURRENT);
				}
			});
			window_menu.append (close);

			window_menu.show_all ();
		}

		public void show_window_menu (Gala.WindowFlags flags, int x, int y)
		{
			if (window_menu == null) {
				init_window_menu ();
			}

			minimize.visible = Gala.WindowFlags.CAN_MINIMIZE in flags;
			maximize.visible = Gala.WindowFlags.CAN_MAXIMIZE in flags;
			maximize.label = Gala.WindowFlags.IS_MAXIMIZED in flags ? _("Unmaximize") : _("Maximize");
			move.visible = Gala.WindowFlags.ALLOWS_MOVE in flags;
			resize.visible = Gala.WindowFlags.ALLOWS_RESIZE in flags;
			always_on_top.active = Gala.WindowFlags.ALWAYS_ON_TOP in flags;
			on_visible_workspace.active = Gala.WindowFlags.ON_ALL_WORKSPACES in flags;
			move_right.visible = !on_visible_workspace.active;
			move_left.visible = !on_visible_workspace.active;
			close.visible = Gala.WindowFlags.CAN_CLOSE in flags;

			window_menu.popup (null, null, null, 3, Gdk.CURRENT_TIME);
		}
	}
}
