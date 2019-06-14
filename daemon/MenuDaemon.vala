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

namespace Gala
{
	const string DBUS_NAME = "org.pantheon.gala";
	const string DBUS_OBJECT_PATH = "/org/pantheon/gala";

	const string DAEMON_DBUS_NAME = "org.pantheon.gala.daemon";
	const string DAEMON_DBUS_OBJECT_PATH = "/org/pantheon/gala/daemon";

	[DBus (name = "org.pantheon.gala")]
	public interface WMDBus : GLib.Object
	{
		public abstract void perform_action (Gala.ActionType type) throws DBusError, IOError;
	}

	[DBus (name = "org.pantheon.gala.daemon")]
	public class MenuDaemon : Object
	{
		Gtk.Menu? window_menu = null;
		Gtk.MenuItem minimize;
		Gtk.MenuItem maximize;
		Gtk.MenuItem move;
		Gtk.MenuItem resize;
		Gtk.CheckMenuItem always_on_top;
		Gtk.CheckMenuItem on_visible_workspace;
		Gtk.MenuItem move_left;
		Gtk.MenuItem move_right;
		Gtk.MenuItem close;

		WMDBus? wm_proxy = null;
		
		ulong always_on_top_sid = 0U;
		ulong on_visible_workspace_sid = 0U;

		[DBus (visible = false)]
		public void setup_dbus ()
		{
			var flags = BusNameOwnerFlags.ALLOW_REPLACEMENT | BusNameOwnerFlags.REPLACE;
			Bus.own_name (BusType.SESSION, DAEMON_DBUS_NAME, flags, on_bus_acquired, () => {}, null);

			Bus.watch_name (BusType.SESSION, DBUS_NAME, BusNameWatcherFlags.NONE, gala_appeared, lost_gala);
		}

		void on_gala_get (GLib.Object? o, GLib.AsyncResult? res)
		{
			try {
				wm_proxy = Bus.get_proxy.end (res);
			} catch (Error e) {
				warning ("Failed to get Gala proxy: %s", e.message);
			}
		}

		void lost_gala ()
		{
			wm_proxy = null;
		}

		void gala_appeared ()
		{
			if (wm_proxy == null) {
				Bus.get_proxy.begin<WMDBus> (BusType.SESSION, DBUS_NAME, DBUS_OBJECT_PATH, 0, null, on_gala_get);
			}
		}

		void on_bus_acquired (DBusConnection conn)
		{
			try {
				conn.register_object (DAEMON_DBUS_OBJECT_PATH, this);
			} catch (Error e) {
				stderr.printf ("Error registering MenuDaemon: %s\n", e.message);
			}
		}

		void perform_action (Gala.ActionType type)
		{
			if (wm_proxy != null) {
				try {
					wm_proxy.perform_action (type);
				} catch (Error e) {
					warning ("Failed to perform Gala action over DBus: %s", e.message);
				}
			}
		}

		void init_window_menu ()
		{
			window_menu = new Gtk.Menu ();

			minimize = new Gtk.MenuItem.with_label (_("Minimize"));
			minimize.activate.connect (() => {
				perform_action (Gala.ActionType.MINIMIZE_CURRENT);
			});
			window_menu.append (minimize);

			maximize = new Gtk.MenuItem.with_label ("");
			maximize.activate.connect (() => {
				perform_action (Gala.ActionType.MAXIMIZE_CURRENT);
			});
			window_menu.append (maximize);

			move = new Gtk.MenuItem.with_label (_("Move"));
			move.activate.connect (() => {
				perform_action (Gala.ActionType.START_MOVE_CURRENT);
			});
			window_menu.append (move);

			resize = new Gtk.MenuItem.with_label (_("Resize"));
			resize.activate.connect (() => {
				perform_action (Gala.ActionType.START_RESIZE_CURRENT);
			});
			window_menu.append (resize);

			always_on_top = new Gtk.CheckMenuItem.with_label (_("Always on Top"));
			always_on_top_sid = always_on_top.activate.connect (() => {
				perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_TOP_CURRENT);
			});
			window_menu.append (always_on_top);

			on_visible_workspace = new Gtk.CheckMenuItem.with_label (_("Always on Visible Workspace"));
			on_visible_workspace_sid = on_visible_workspace.activate.connect (() => {
				perform_action (Gala.ActionType.TOGGLE_ALWAYS_ON_VISIBLE_WORKSPACE_CURRENT);
			});
			window_menu.append (on_visible_workspace);

			move_left = new Gtk.MenuItem.with_label (_("Move to Workspace Left"));
			move_left.activate.connect (() => {
				perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_LEFT);
			});
			window_menu.append (move_left);

			move_right = new Gtk.MenuItem.with_label (_("Move to Workspace Right"));
			move_right.activate.connect (() => {
				perform_action (Gala.ActionType.MOVE_CURRENT_WORKSPACE_RIGHT);
			});
			window_menu.append (move_right);

			close = new Gtk.MenuItem.with_label (_("Close"));
			close.activate.connect (() => {
				perform_action (Gala.ActionType.CLOSE_CURRENT);
			});
			window_menu.append (close);

			window_menu.show_all ();
		}

		public void show_window_menu (Gala.WindowFlags flags, int x, int y) throws DBusError, IOError
		{
			if (window_menu == null) {
				init_window_menu ();
			}

			minimize.visible = Gala.WindowFlags.CAN_MINIMIZE in flags;
			maximize.visible = Gala.WindowFlags.CAN_MAXIMIZE in flags;
			maximize.label = Gala.WindowFlags.IS_MAXIMIZED in flags ? _("Unmaximize") : _("Maximize");
			move.visible = Gala.WindowFlags.ALLOWS_MOVE in flags;
			resize.visible = Gala.WindowFlags.ALLOWS_RESIZE in flags;
			
			// Setting active causes signal fires on activate so
			// we temporarily block those signals from emissions
			SignalHandler.block (always_on_top, always_on_top_sid);
			SignalHandler.block (on_visible_workspace, on_visible_workspace_sid);

			always_on_top.active = Gala.WindowFlags.ALWAYS_ON_TOP in flags;
			on_visible_workspace.active = Gala.WindowFlags.ON_ALL_WORKSPACES in flags;
			
			SignalHandler.unblock (always_on_top, always_on_top_sid);
			SignalHandler.unblock (on_visible_workspace, on_visible_workspace_sid);

			move_right.visible = !on_visible_workspace.active;
			move_left.visible = !on_visible_workspace.active;
			close.visible = Gala.WindowFlags.CAN_CLOSE in flags;

			window_menu.popup (null, null, (m, ref px, ref py, out push_in) => {
				var scale = m.scale_factor;
				px = x / scale;
				// Move the menu 1 pixel outside of the pointer or else it closes instantly
				// on the mouse up event
				py = (y / scale) + 1;
				push_in = true;
			}, 3, Gdk.CURRENT_TIME);
		}
	}
}
