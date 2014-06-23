//
//  Copyright (C) 2014 Tom Beckmann
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

using Clutter;
using Meta;

namespace Gala
{
	public class MultitaskingView : Actor
	{
		const int HIDING_DURATION = 300;

		public WindowManager wm { get; construct; }

		Meta.Screen screen;
		bool opened;

		List<MonitorClone> window_containers_monitors;

		IconGroupContainer icon_groups;
		Actor workspaces;

		public MultitaskingView (WindowManager wm)
		{
			Object (wm: wm);
		}

		construct
		{
			visible = false;
			reactive = true;
			clip_to_allocation = true;

			opened = false;
			screen = wm.get_screen ();

			workspaces = new Actor ();
			workspaces.set_easing_mode (AnimationMode.EASE_OUT_QUAD);

			icon_groups = new IconGroupContainer (screen);

			add_child (icon_groups);
			add_child (workspaces);

			foreach (var workspace in screen.get_workspaces ())
				add_workspace (workspace.index ());

			screen.workspace_added.connect (add_workspace);
			screen.workspace_removed.connect (remove_workspace);
			screen.workspace_switched.connect_after ((from, to, direction) => {
				update_positions (opened);
			});

			window_containers_monitors = new List<MonitorClone> ();
			update_monitors ();
			screen.monitors_changed.connect (update_monitors);

			Prefs.add_listener ((pref) => {
				if (pref == Preference.WORKSPACES_ONLY_ON_PRIMARY) {
					update_monitors ();
					return;
				}

				if (Prefs.get_dynamic_workspaces () ||
					(pref != Preference.DYNAMIC_WORKSPACES && pref != Preference.NUM_WORKSPACES))
					return;

				Idle.add (() => {
					unowned List<Workspace> existing_workspaces = screen.get_workspaces ();

					foreach (var child in workspaces.get_children ()) {
						unowned WorkspaceClone workspace_clone = (WorkspaceClone) child;
						if (existing_workspaces.index (workspace_clone.workspace) < 0) {
							workspace_clone.window_selected.disconnect (window_selected);
							workspace_clone.selected.disconnect (activate_workspace);

							icon_groups.remove_group (workspace_clone.icon_group);

							workspace_clone.destroy ();
						}
					}

					update_monitors ();
					update_positions (false);

					return false;
				});
			});
		}

		void update_monitors ()
		{
			foreach (var monitor_clone in window_containers_monitors)
				monitor_clone.destroy ();

			var primary = screen.get_primary_monitor ();

			if (InternalUtils.workspaces_only_on_primary ()) {
				for (var monitor = 0; monitor < screen.get_n_monitors (); monitor++) {
					if (monitor == primary)
						continue;

					var monitor_clone = new MonitorClone (wm, monitor);
					monitor_clone.window_selected.connect (window_selected);
					monitor_clone.visible = opened;

					window_containers_monitors.append (monitor_clone);
					wm.ui_group.add_child (monitor_clone);
				}
			}

			var primary_geometry = screen.get_monitor_geometry (primary);

			set_position (primary_geometry.x, primary_geometry.y);
			set_size (primary_geometry.width, primary_geometry.height);
		}

		public override void key_focus_out ()
		{
			if (opened && !contains (get_stage ().key_focus))
				toggle ();
		}

		public override bool scroll_event (ScrollEvent event)
		{
			if (event.direction == ScrollDirection.SMOOTH)
				return false;

			// don't allow scrolling while switching to limit the rate at which
			// workspaces are skipped during a scroll motion
			if (workspaces.get_transition ("x") != null)
				return false;

			var active_workspace = screen.get_active_workspace ();
			var new_workspace = active_workspace.get_neighbor (
					event.direction == ScrollDirection.UP || event.direction == ScrollDirection.LEFT ?
					Meta.MotionDirection.LEFT : Meta.MotionDirection.RIGHT);

			if (active_workspace != new_workspace)
				new_workspace.activate (screen.get_display ().get_current_time ());

			return false;
		}

		void update_positions (bool animate)
		{
			var active_index = screen.get_active_workspace ().index ();
			var active_x = 0.0f;

			foreach (var child in workspaces.get_children ()) {
				unowned WorkspaceClone workspace_clone = (WorkspaceClone) child;
				var index = workspace_clone.workspace.index ();
				var dest_x = index * (workspace_clone.width - 150);

				if (index == active_index) {
					active_x = dest_x;
					workspace_clone.active = true;
				} else {
					workspace_clone.active = false;
				}

				workspace_clone.set_easing_duration (animate ? 200 : 0);
				workspace_clone.x = dest_x;
			}

			workspaces.set_easing_duration (animate ? 300 : 0);
			workspaces.x = -active_x;

			if (animate) {
				icon_groups.save_easing_state ();
				icon_groups.set_easing_mode (AnimationMode.EASE_OUT_QUAD);
				icon_groups.set_easing_duration (200);
			}

			// make sure the active workspace's icongroup is always visible
			if (icon_groups.width > width) {
				icon_groups.x = (-active_index * (IconGroupContainer.SPACING + IconGroup.SIZE) + width / 2)
					.clamp (width - icon_groups.width - 64, 64);
			} else
				icon_groups.x = width / 2 - icon_groups.width / 2;

			if (animate)
				icon_groups.restore_easing_state ();
		}

		void add_workspace (int num)
		{
			var workspace = new WorkspaceClone (wm, screen.get_workspace_by_index (num));
			workspace.window_selected.connect (window_selected);
			workspace.selected.connect (activate_workspace);

			workspaces.insert_child_at_index (workspace, num);
			icon_groups.add_group (workspace.icon_group);

			update_positions (opened);

			if (opened)
				workspace.open ();
		}

		void remove_workspace (int num)
		{
			WorkspaceClone? workspace = null;

			// FIXME is there a better way to get the removed workspace?
			unowned List<Meta.Workspace> existing_workspaces = screen.get_workspaces ();

			foreach (var child in workspaces.get_children ()) {
				unowned WorkspaceClone clone = (WorkspaceClone) child;
				if (existing_workspaces.index (clone.workspace) < 0) {
					workspace = clone;
					break;
				}
			}

			if (workspace == null)
				return;

			workspace.window_selected.disconnect (window_selected);
			workspace.selected.disconnect (activate_workspace);

			workspace.icon_group.set_easing_duration (200);
			workspace.icon_group.set_easing_mode (AnimationMode.LINEAR);
			workspace.icon_group.opacity = 0;
			var transition = workspace.icon_group.get_transition ("opacity");
			if (transition != null)
				transition.completed.connect (() => {
					icon_groups.remove_group (workspace.icon_group);
				});
			else
				icon_groups.remove_group (workspace.icon_group);

			workspace.destroy ();

			update_positions (opened);
		}

		void activate_workspace (WorkspaceClone clone, bool close_view)
		{
			close_view = close_view && screen.get_active_workspace () == clone.workspace;

			clone.workspace.activate (screen.get_display ().get_current_time ());

			if (close_view)
				toggle ();
		}

		public override bool key_press_event (Clutter.KeyEvent event)
		{
			switch (event.keyval) {
				case Clutter.Key.Escape:
					if (opened)
						toggle ();
					break;
				case Clutter.Key.Down:
					select_window (MotionDirection.DOWN);
					break;
				case Clutter.Key.Up:
					select_window (MotionDirection.UP);
					break;
				case Clutter.Key.Left:
					select_window (MotionDirection.LEFT);
					break;
				case Clutter.Key.Right:
					select_window (MotionDirection.RIGHT);
					break;
				case Clutter.Key.Return:
				case Clutter.Key.KP_Enter:
					get_active_workspace_clone ().window_container.activate_selected_window ();
					break;
			}

			return false;
		}

		void select_window (MotionDirection direction)
		{
			get_active_workspace_clone ().window_container.select_next_window (direction);
		}

		WorkspaceClone get_active_workspace_clone ()
		{
			foreach (var child in workspaces.get_children ()) {
				unowned WorkspaceClone workspace_clone = (WorkspaceClone) child;
				if (workspace_clone.workspace == screen.get_active_workspace ()) {
					return workspace_clone;
				}
			}

			assert_not_reached ();
		}

		void window_selected (Meta.Window window)
		{
			var time = screen.get_display ().get_current_time ();
			var workspace = window.get_workspace ();

			if (workspace != screen.get_active_workspace ())
				workspace.activate (time);
			else {
				window.activate (time);
				toggle ();
			}
		}

		public void toggle ()
		{
			opened = !opened;

			var opening = opened;

			foreach (var container in window_containers_monitors) {
				if (opening) {
					container.visible = true;
					container.open ();
				} else
					container.close ();
			}

			if (opening) {
				wm.begin_modal ();
				wm.block_keybindings_in_modal = false;

				wm.background_group.hide ();
				wm.window_group.hide ();
				wm.top_window_group.hide ();
				show ();
				grab_key_focus ();

				icon_groups.y = height - WorkspaceClone.BOTTOM_OFFSET + 20;
			}

			// find active workspace clone and raise it, so there are no overlaps while transitioning
			WorkspaceClone? active_workspace = null;
			var active = screen.get_active_workspace ();
			foreach (var child in workspaces.get_children ()) {
				unowned WorkspaceClone workspace = (WorkspaceClone) child;
				if (workspace.workspace == active) {
					active_workspace = workspace;
					break;
				}
			}
			if (active_workspace != null)
				workspaces.set_child_above_sibling (active_workspace, null);

			update_positions (false);

			foreach (var child in workspaces.get_children ()) {
				unowned WorkspaceClone workspace = (WorkspaceClone) child;
				if (opening)
					workspace.open ();
				else
					workspace.close ();
			}

			if (!opening) {
				Timeout.add (290, () => {
					foreach (var container in window_containers_monitors) {
						container.visible = false;
					}

					hide ();

					wm.background_group.show ();
					wm.window_group.show ();
					wm.top_window_group.show ();

					wm.block_keybindings_in_modal = true;
					wm.end_modal ();

					return false;
				});
			}

			/**
			 * three types of animation for docks:
			 * - window appears to be at the bottom --> slide up
			 * - window appears to be at the top --> slide down
			 * - window appears to be somewhere else --> fade out
			var rect = meta_window.get_outer_rect ();

			if (about_same (rect.y, monitor_geometry.y)) {

				float dest = opening ? monitor_geometry.y - rect.height : rect.y;
				window.animate (AnimationMode.EASE_OUT_QUAD, HIDING_DURATION, y: dest);

			} else if (about_same (rect.y + rect.height,
				monitor_geometry.y + monitor_geometry.height)) {

				float dest = opening ? monitor_geometry.y + monitor_geometry.height : rect.y;
				window.animate (AnimationMode.EASE_OUT_QUAD, HIDING_DURATION, y: dest);

			} else {
				uint dest = opening ? 0 : 255;
				window.animate (AnimationMode.LINEAR, HIDING_DURATION, opacity: dest);
			}
			*/
		}

		/**
		 * checks if val1 is about the same as val2 with a threshold of 2 by default
		 */
		/*private bool about_same (float val1, float val2, float threshold = 2.0f)
		{
			return Math.fabsf (val1 - val2) <= threshold;
		}*/
	}
}

