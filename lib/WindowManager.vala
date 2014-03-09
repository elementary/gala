
namespace Gala
{
	public enum ActionType
	{
		NONE = 0,
		SHOW_WORKSPACE_VIEW,
		MAXIMIZE_CURRENT,
		MINIMIZE_CURRENT,
		OPEN_LAUNCHER,
		CUSTOM_COMMAND,
		WINDOW_OVERVIEW,
		WINDOW_OVERVIEW_ALL
	}
	
	public enum InputArea
	{
		NONE,
		FULLSCREEN,
		HOT_CORNER
	}

	public interface WindowManager : Meta.Plugin
	{
		public abstract Clutter.Actor ui_group { get; protected set; }
		public abstract Meta.BackgroundGroup background_group { get; protected set; }
		public abstract Clutter.Stage stage { get; protected set; }

		public abstract void begin_modal ();
		public abstract void end_modal ();
		public abstract void perform_action (ActionType type);
		public abstract void update_input_area ();
		public abstract void move_window (Meta.Window? window, Meta.MotionDirection direction);
	}
}

