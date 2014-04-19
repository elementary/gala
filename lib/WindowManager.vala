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
		public abstract Clutter.Stage stage { get; protected set; }
		public abstract Clutter.Actor window_group { get; protected set; }
		public abstract Clutter.Actor top_window_group { get; protected set; }
		public abstract Meta.BackgroundGroup background_group { get; protected set; }

		public abstract void begin_modal ();
		public abstract void end_modal ();
		public abstract void perform_action (ActionType type);
		public abstract void update_input_area ();
		public abstract void move_window (Meta.Window? window, Meta.MotionDirection direction);
		public abstract void switch_to_next_workspace (Meta.MotionDirection direction);
	}
}

