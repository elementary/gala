using Meta;

namespace Gala
{
	public enum ActionType
	{
		SHOW_WORKSPACE_VIEW,
		WORKSPACE_LEFT,
		WORKSPACE_RIGHT,
		MOVE_TO_WORKSPACE_LEFT,
		MOVE_TO_WORKSPACE_RIGHT,
		MAXIMIZE_CURRENT,
		MINIMIZE_CURRENT,
		CLOSE_CURRENT,
		OPEN_LAUNCHER
	}
	
	public class Action
	{
		public static void run (Plugin plugin, ActionType type)
		{
			var screen = plugin.get_screen ();
			var display = screen.get_display ();
			
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
					plugin.move_window (display.get_focus_window (), MotionDirection.LEFT);
					break;
				case ActionType.MOVE_TO_WORKSPACE_RIGHT:
					plugin.move_window (display.get_focus_window (), MotionDirection.RIGHT);
					break;
				case ActionType.MAXIMIZE_CURRENT:
					display.get_focus_window ().maximize (MaximizeFlags.HORIZONTAL | MaximizeFlags.VERTICAL);
					break;
				case ActionType.MINIMIZE_CURRENT:
					display.get_focus_window ().minimize ();
					break;
				case ActionType.CLOSE_CURRENT:
					display.get_focus_window ().delete (display.get_current_time ());
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
