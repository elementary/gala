//
//  Copyright (C) 2014 Tom Beckmann, Rico Tzschichholz
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

using Meta;

namespace Gala
{
	public class WorkspaceManager : Object
	{
		public Screen screen { get; construct; }
		/**
		 * While set to true, workspaces that have no windows left will be
		 * removed immediately. Otherwise they will be kept alive until
		 * the user switches away from them. Only applies to dynamic workspaces.
		 */
		public bool remove_workspace_immediately { get; set; default = false; }

		public WorkspaceManager (Screen screen)
		{
			Object (screen: screen);

			if (Prefs.get_dynamic_workspaces ())
				screen.override_workspace_layout (ScreenCorner.TOPLEFT, false, 1, -1);

			for (var i = 0; i < screen.get_n_workspaces (); i++)
				workspace_added (screen, i);

			Prefs.add_listener (prefs_listener);

			screen.workspace_added.connect (workspace_added);
			screen.workspace_switched.connect_after (workspace_switched);

			// make sure the last workspace has no windows on it
			if (Prefs.get_dynamic_workspaces ()
				&& Utils.get_n_windows (screen.get_workspace_by_index (screen.get_n_workspaces () - 1)) > 0)
				append_workspace ();
		}

		~WorkspaceManager ()
		{
			Prefs.remove_listener (prefs_listener);

			screen.workspace_added.disconnect (workspace_added);
			screen.workspace_switched.disconnect (workspace_switched);
		}

		void workspace_added (Screen screen, int index)
		{
			var workspace = screen.get_workspace_by_index (index);
			if (workspace == null)
				return;

			workspace.window_added.connect (window_added);
			workspace.window_removed.connect (window_removed);
		}

		void workspace_switched (Screen screen, int from, int to, MotionDirection direction)
		{
			if (!Prefs.get_dynamic_workspaces ())
				return;

			// remove empty workspaces after we switched away from them unless it's the last one
			var prev_workspace = screen.get_workspace_by_index (from);
			if (Utils.get_n_windows (prev_workspace) < 1
				&& from != screen.get_n_workspaces () - 1) {
				remove_workspace (prev_workspace);
			}
		}

		void window_added (Workspace workspace, Window window)
		{
			if (!Prefs.get_dynamic_workspaces ())
				return;

			if ((window.window_type == WindowType.NORMAL
				|| window.window_type == WindowType.DIALOG
				|| window.window_type == WindowType.MODAL_DIALOG)
				&& workspace.index () == screen.get_n_workspaces () - 1)
				append_workspace ();
		}

		void window_removed (Workspace workspace, Window window)
		{
			if (!Prefs.get_dynamic_workspaces ())
				return;

			if (window.window_type != WindowType.NORMAL
				&& window.window_type != WindowType.DIALOG
				&& window.window_type != WindowType.MODAL_DIALOG)
				return;

			var index = screen.get_workspaces ().index (workspace);
			// has already been removed
			if (index < 0)
				return;

			var is_active_workspace = workspace == screen.get_active_workspace ();

			// remove it right away if it was the active workspace and it's not the very last
			// or we are requested to immediately remove the workspace anyway
			if ((!is_active_workspace || remove_workspace_immediately)
				&& Utils.get_n_windows (workspace) < 1
				&& index != screen.get_n_workspaces () - 1) {
				remove_workspace (workspace);
			}
		}

		void prefs_listener (Meta.Preference pref)
		{
			if (pref == Preference.DYNAMIC_WORKSPACES && Prefs.get_dynamic_workspaces ()) {
				// if the last workspace has a window, we need to append a new workspace
				if (Utils.get_n_windows (screen.get_workspace_by_index (screen.get_n_workspaces () - 1)) > 0)
					append_workspace ();

			} else if ((pref == Preference.DYNAMIC_WORKSPACES
				|| pref == Preference.NUM_WORKSPACES)
				&& !Prefs.get_dynamic_workspaces ()) {

				var time = screen.get_display ().get_current_time ();
				var n_workspaces = screen.get_n_workspaces ();

				/* TODO check if this is still needed
				// only need to listen for the case when workspaces were removed.
				// Any other case will be caught by the workspace_added signal.
				// For some reason workspace_removed is not emitted, when changing the workspace number
				if (Prefs.get_num_workspaces () < n_workspaces) {
					for (int i = Prefs.get_num_workspaces () - 1; i < n_workspaces; i++) {
						screen.remove_workspace (screen.get_workspace_by_index (i), time);
					}
				}*/
			}
		}

		void append_workspace ()
		{
			screen.append_new_workspace (false, screen.get_display ().get_current_time ());
		}

		/**
		 * Make sure we switch to a different workspace and remove the given one
		 *
		 * @param workspace The workspace to remove
		 */
		void remove_workspace (Workspace workspace)
		{
			var time = screen.get_display ().get_current_time ();

			if (workspace == screen.get_active_workspace ()) {
				Workspace? next = null;

				next = workspace.get_neighbor (MotionDirection.LEFT);
				// if it's the first one we may have another one to the right
				if (next == workspace || next == null)
					next = workspace.get_neighbor (MotionDirection.RIGHT);

				if (next != null)
					next.activate (time);
			}

			screen.remove_workspace (workspace, time);
		}
	}
}

