using Clutter;

namespace Gala
{
	public class MultitaskingView : Actor
	{
		public Meta.Screen screen { get; construct set; }
		public Plugin plugin { get; construct set; }

		Actor icon_groups;
		Actor workspaces;

		public bool opened { get; private set; default = false; }

		const int HIDING_DURATION = 300;

		public MultitaskingView (Plugin plugin)
		{
			Object (plugin: plugin, screen: plugin.get_screen ());

			visible = false;
			reactive = true;

			workspaces = new Actor ();

			icon_groups = new Actor ();
			icon_groups.layout_manager = new BoxLayout ();
			(icon_groups.layout_manager as BoxLayout).spacing = 48;

			add_child (icon_groups);
			add_child (workspaces);

			foreach (var workspace in screen.get_workspaces ())
				add_workspace (workspace.index ());

			screen.workspace_added.connect (add_workspace);
			screen.workspace_removed.connect (remove_workspace);
			screen.workspace_switched.connect ((from, to, direction) => {
				update_positions (opened);
			});
		}

		public override bool scroll_event (ScrollEvent event)
		{
			var active_workspace = screen.get_active_workspace ();
			var new_workspace = active_workspace.get_neighbor (
					event.direction == ScrollDirection.LEFT ||
					event.direction == ScrollDirection.UP ?
						Meta.MotionDirection.LEFT : Meta.MotionDirection.RIGHT);
			if (active_workspace != new_workspace)
				new_workspace.activate (screen.get_display ().get_current_time ());

			return false;
		}

		void update_positions (bool animate = false, bool closing = false)
		{
			float x = 0;
			WorkspaceClone? active = null;
			var active_index = screen.get_active_workspace ().index ();;

			foreach (var child in workspaces.get_children ()) {
				var workspace_clone = child as WorkspaceClone;
				var index = workspace_clone.workspace.index ();

				if (index == active_index)
					active = workspace_clone;

				workspace_clone.x = index * (workspace_clone.width - 150);
			}

			if (active != null) {
				var dest_x = -active.x;
				if (animate)
					workspaces.animate (AnimationMode.EASE_OUT_QUAD, 300, x: dest_x);
				else
					workspaces.x = dest_x;
			}
		}

		void add_workspace (int num)
		{
			var workspace = new WorkspaceClone (screen.get_workspace_by_index (num));
			workspace.window_selected.connect (window_selected);
			workspace.selected.connect (activate_workspace);

			workspaces.insert_child_at_index (workspace, num);
			icon_groups.insert_child_at_index (workspace.icon_group, num);

			update_positions ();
		}

		void remove_workspace (int num)
		{
			WorkspaceClone? workspace = null;

			// FIXME is there a better way to get the removed workspace?
			unowned List<Meta.Workspace> existing_workspaces = screen.get_workspaces ();

			foreach (var child in workspaces.get_children ()) {
				var clone = child as WorkspaceClone;

				if (existing_workspaces.index (clone.workspace) < 0) {
					workspace = clone;
					break;
				}
			}

			if (workspace == null)
				return;

			workspace.window_selected.disconnect (window_selected);
			workspace.selected.disconnect (activate_workspace);
			workspace.icon_group.destroy ();
			workspace.destroy ();

			update_positions ();
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
			if (event.keyval == Clutter.Key.Escape)
				toggle ();

			return false;
		}

		void window_selected (Meta.Window window)
		{
			window.activate (screen.get_display ().get_current_time ());
			toggle ();
		}

		public void toggle ()
		{
			opened = !opened;

			var opening = opened;

			unowned List<Meta.WindowActor> windows = Meta.Compositor.get_window_actors (screen);
			var primary_monitor = screen.get_primary_monitor ();
			var monitor = screen.get_monitor_geometry (primary_monitor);

			if (opening) {
				plugin.begin_modal ();

				plugin.background_group.hide ();
				plugin.window_group.hide ();
				plugin.top_window_group.hide ();
				show ();
				grab_key_focus ();

				icon_groups.x = monitor.width / 2 - icon_groups.width / 2;
				icon_groups.y = monitor.height - WorkspaceClone.BOTTOM_OFFSET + 20;
			}

			// find active workspace clone and raise it, so there are no overlaps while transitioning
			WorkspaceClone? active_workspace = null;
			var active = screen.get_active_workspace ();
			foreach (var child in workspaces.get_children ()) {
				var workspace = child as WorkspaceClone;
				if (workspace.workspace == active) {
					active_workspace = workspace;
					break;
				}
			}
			if (active_workspace != null)
				workspaces.set_child_above_sibling (active_workspace, null);

			update_positions (false);

			foreach (var child in workspaces.get_children ()) {
				if (opening)
					(child as WorkspaceClone).open ();
				else
					(child as WorkspaceClone).close ();
			}

			if (!opening) {
				Timeout.add (290, () => {
					hide ();

					plugin.background_group.show ();
					plugin.window_group.show ();
					plugin.top_window_group.show ();

					plugin.end_modal ();

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
		private bool about_same (float val1, float val2, float threshold = 2.0f)
		{
			return Math.fabsf (val1 - val2) <= threshold;
		}
	}
}

