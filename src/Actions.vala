using Meta;

namespace Gala
{
	public enum ActionType
	{
		NONE = 0,
		SHOW_WORKSPACE_VIEW = 1,
		WORKSPACE_LEFT = 2,
		WORKSPACE_RIGHT = 3,
		MOVE_TO_WORKSPACE_LEFT = 4,
		MOVE_TO_WORKSPACE_RIGHT = 5,
		MAXIMIZE_CURRENT = 6,
		MINIMIZE_CURRENT = 7,
		CLOSE_CURRENT = 8,
		OPEN_LAUNCHER = 9
	}
	
	public class Action
	{
		public static void run (Plugin plugin, ActionType type)
		{
			var screen = plugin.get_screen ();
			var display = screen.get_display ();
			var current = display.get_focus_window ();
			
			switch (type) {
				case ActionType.SHOW_WORKSPACE_VIEW:
					plugin.workspace_view.show ();
					break;
				case ActionType.WORKSPACE_LEFT:
					plugin.workspace_view.switch_to_next_workspace (MotionDirection.LEFT);
					break;
				case ActionType.WORKSPACE_RIGHT:
					plugin.workspace_view.switch_to_next_workspace (MotionDirection.RIGHT);
					break;
				case ActionType.MOVE_TO_WORKSPACE_LEFT:
					plugin.move_window (current, MotionDirection.LEFT);
					break;
				case ActionType.MOVE_TO_WORKSPACE_RIGHT:
					plugin.move_window (current, MotionDirection.RIGHT);
					break;
				case ActionType.MAXIMIZE_CURRENT:
					if (current == null)
						break;
					if (current.get_maximized () == (MaximizeFlags.HORIZONTAL | MaximizeFlags.VERTICAL))
						current.unmaximize (MaximizeFlags.HORIZONTAL | MaximizeFlags.VERTICAL);
					else
						current.maximize (MaximizeFlags.HORIZONTAL | MaximizeFlags.VERTICAL);
					break;
				case ActionType.MINIMIZE_CURRENT:
					if (current != null)
						current.minimize ();
					break;
				case ActionType.CLOSE_CURRENT:
					if (current != null)
						current.delete (display.get_current_time ());
					break;
				case ActionType.OPEN_LAUNCHER:
					try {
						Process.spawn_command_line_async (BehaviorSettings.get_default ().panel_main_menu_action);
					} catch (Error e) {
						warning (e.message);
					}
					break;
				default:
					warning ("Trying to run unknown action");
					break;
			}
		}
	}
}
