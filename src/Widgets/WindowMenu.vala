//
//  Copyright (C) 2014 Gala Developers
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
//  Authored By: Tom Beckmann
//

namespace Gala
{
	/**
	 * GtkMenu that is spawned on windows e.g. by rightclick on titlebar
	 * Prior to mutter3.14 this was provided by libmutter
	 */
	public class WindowMenu : Gtk.Menu
	{
		ulong always_on_top_handler_id;
		ulong on_visible_workspace_handler_id;

		public Meta.Window current_window {
			get {
				return _current_window;
			}
			set {
				SignalHandler.block (always_on_top, always_on_top_handler_id);
				SignalHandler.block (on_visible_workspace, on_visible_workspace_handler_id);

				_current_window = value;
				update_window ();

				SignalHandler.unblock (always_on_top, always_on_top_handler_id);
				SignalHandler.unblock (on_visible_workspace, on_visible_workspace_handler_id);
			}
		}

		Meta.Window _current_window;

		Gtk.MenuItem minimize;
		Gtk.MenuItem maximize;
		Gtk.MenuItem move;
		Gtk.MenuItem resize;
		Gtk.CheckMenuItem always_on_top;
		Gtk.CheckMenuItem on_visible_workspace;
		Gtk.MenuItem move_left;
		Gtk.MenuItem move_right;
		Gtk.MenuItem close;

		public WindowMenu ()
		{
		}

		construct
		{
			minimize = new Gtk.MenuItem.with_label (_("Minimize"));
			minimize.activate.connect (() => {
				current_window.minimize ();
			});
			append (minimize);

			maximize = new Gtk.MenuItem.with_label ("");
			maximize.activate.connect (() => {
				if (current_window.get_maximized () > 0)
					current_window.unmaximize (Meta.MaximizeFlags.BOTH);
				else
					current_window.maximize (Meta.MaximizeFlags.BOTH);
			});
			append (maximize);

			move = new Gtk.MenuItem.with_label (_("Move"));
			move.activate.connect (() => {
				current_window.begin_grab_op (Meta.GrabOp.KEYBOARD_MOVING, true,
					Gtk.get_current_event_time ());
			});
			append (move);

			resize = new Gtk.MenuItem.with_label (_("Resize"));
			resize.activate.connect (() => {
				current_window.begin_grab_op (Meta.GrabOp.KEYBOARD_RESIZING_UNKNOWN, true,
					Gtk.get_current_event_time ());
			});
			append (resize);

			always_on_top = new Gtk.CheckMenuItem.with_label (_("Always on Top"));
			always_on_top_handler_id = always_on_top.activate.connect (() => {
				if (current_window.is_above ())
					current_window.unmake_above ();
				else
					current_window.make_above ();
			});
			append (always_on_top);

			on_visible_workspace = new Gtk.CheckMenuItem.with_label (_("Always on Visible Workspace"));
			on_visible_workspace_handler_id = on_visible_workspace.activate.connect (() => {
				if (current_window.on_all_workspaces)
					current_window.unstick ();
				else
					current_window.stick ();
			});
			append (on_visible_workspace);

			move_left = new Gtk.MenuItem.with_label (_("Move to Workspace Left"));
			move_left.activate.connect (() => {
				var wp = current_window.get_workspace ().get_neighbor (Meta.MotionDirection.LEFT);
				if (wp != null)
					current_window.change_workspace (wp);
			});
			append (move_left);

			move_right = new Gtk.MenuItem.with_label (_("Move to Workspace Right"));
			move_right.activate.connect (() => {
				var wp = current_window.get_workspace ().get_neighbor (Meta.MotionDirection.RIGHT);
				if (wp != null)
					current_window.change_workspace (wp);
			});
			append (move_right);

			close = new Gtk.MenuItem.with_label (_("Close"));
			close.activate.connect (() => {
				current_window.@delete (Gtk.get_current_event_time ());
			});
			append (close);
		}

		void update_window ()
		{
			minimize.visible = current_window.can_minimize ();

			maximize.visible = current_window.can_maximize ();
			maximize.label = current_window.get_maximized () > 0 ? _("Unmaximize") : _("Maximize");

			move.visible = current_window.allows_move ();

			resize.visible = current_window.allows_resize ();

			always_on_top.active = current_window.is_above ();

			on_visible_workspace.active = current_window.on_all_workspaces;

			move_right.visible = !current_window.on_all_workspaces;

			move_left.visible = !current_window.on_all_workspaces;

			close.visible = current_window.can_close ();
		}
	}
}
