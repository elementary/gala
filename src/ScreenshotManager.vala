//
//  Copyright (C) 2016 Rico Tzschichholz
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
	[DBus (name="org.gnome.Shell.Screenshot")]
	public class ScreenshotManager : Object
	{
		static ScreenshotManager? instance;

		[DBus (visible = false)]
		public static unowned ScreenshotManager init (WindowManager wm)
		{
			if (instance == null)
				instance = new ScreenshotManager (wm);

			return instance;
		}

		WindowManager wm;

		ScreenshotManager (WindowManager _wm)
		{
			wm = _wm;
		}

		public void flash_area (int x, int y, int width, int height)
		{
			warning ("FlashArea not implemented");
		}

		public void screenshot (bool include_cursor, bool flash, string filename, out bool success, out string filename_used)
		{
			warning ("Screenshot not implemented");
			filename_used = "";
			success = false;
		}

		public void screenshot_area (int x, int y, int width, int height, bool flash, string filename, out bool success, out string filename_used)
		{
			warning ("ScreenShotArea not implemented");
			filename_used = "";
			success = false;
		}

		public void screenshot_window (bool include_frame, bool include_cursor, bool flash, string filename, out bool success, out string filename_used)
		{
			warning ("ScreenShotWindow not implemented");
			filename_used = "";
			success = false;
		}

		public void select_area (out int x, out int y, out int width, out int height)
		{
			warning ("SelectArea not implemented");
			x = y = width = height = 0;
		}
	}
}
