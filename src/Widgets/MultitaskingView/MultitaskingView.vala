using Clutter;
using Meta;

namespace Gala
{
	public class MultitaskingView : Actor
	{
		const int HIDING_DURATION = 300;

		public Meta.Screen screen { get; construct set; }
		public WindowManager wm { get; construct set; }
		public bool opened { get; private set; default = false; }

		Actor icon_groups;
		Actor workspaces;

		public MultitaskingView (WindowManager wm)
		{
			Object (wm: wm, screen: wm.get_screen ());

			visible = false;
			reactive = true;

			workspaces = new Actor ();
			workspaces.set_easing_mode (AnimationMode.EASE_OUT_QUAD);

			icon_groups = new Actor ();
			icon_groups.layout_manager = new BoxLayout ();
			(icon_groups.layout_manager as BoxLayout).spacing = 48;

			add_child (icon_groups);
			add_child (workspaces);

			foreach (var workspace in screen.get_workspaces ())
				add_workspace (workspace.index ());

			screen.workspace_added.connect (add_workspace);
			screen.workspace_removed.connect (remove_workspace);
			screen.workspace_switched.connect_after ((from, to, direction) => {
				update_positions (opened);
			});
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

			var active_workspace = screen.get_active_workspace ();
			var new_workspace = active_workspace.get_neighbor (
					event.direction == ScrollDirection.UP || event.direction == ScrollDirection.LEFT ?
					Meta.MotionDirection.LEFT : Meta.MotionDirection.RIGHT);

			if (active_workspace != new_workspace)
				new_workspace.activate (screen.get_display ().get_current_time ());

			return false;
		}

		void update_positions (bool animate = false)
		{
			var active_index = screen.get_active_workspace ().index ();
			var active_x = 0.0f;

			foreach (var child in workspaces.get_children ()) {
				var workspace_clone = child as WorkspaceClone;
				var index = workspace_clone.workspace.index ();
				var dest_x = index * (workspace_clone.width - 150);

				if (index == active_index)
					active_x = dest_x;

				workspace_clone.set_easing_duration (animate ? 200 : 0);
				workspace_clone.x = dest_x;
			}

			workspaces.set_easing_duration (animate ? 300 : 0);
			workspaces.x = -active_x;
		}

		void add_workspace (int num)
		{
			var workspace = new WorkspaceClone (screen.get_workspace_by_index (num), wm);
			workspace.window_selected.connect (window_selected);
			workspace.selected.connect (activate_workspace);

			workspaces.insert_child_at_index (workspace, num);
			icon_groups.insert_child_at_index (workspace.icon_group, num);

			update_positions ();

			if (opened)
				workspace.open ();
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

			workspace.icon_group.set_easing_duration (200);
			workspace.icon_group.set_easing_mode (AnimationMode.LINEAR);
			workspace.icon_group.opacity = 0;
			var transition = workspace.icon_group.get_transition ("opacity");
			if (transition != null)
				transition.completed.connect (() => {
					workspace.icon_group.destroy ();
				});
			else
				workspace.icon_group.destroy ();
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
			}

			return false;
		}

		void select_window (MotionDirection direction)
		{
			foreach (var child in workspaces.get_children ()) {
				var workspace_clone = child as WorkspaceClone;
				if (workspace_clone.workspace == screen.get_active_workspace ())
					workspace_clone.window_container.select_next_window (direction);
			}
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
				wm.begin_modal ();
				wm.block_keybindings_in_modal = false;

				wm.background_group.hide ();
				wm.window_group.hide ();
				wm.top_window_group.hide ();
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

