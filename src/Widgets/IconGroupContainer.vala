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
	/**
	 * This class contains the icon groups at the bottom and will take
	 * care of displaying actors for inserting windows between the groups
	 * once implemented
	 */
	public class IconGroupContainer : Actor
	{
		public static const int SPACING = 48;
		public static const int GROUP_WIDTH = 64;

		public Screen screen { get; construct; }

		public IconGroupContainer (Screen screen)
		{
			Object (screen: screen);
		}

		void update_positions ()
		{
			unowned List<Workspace> existing_workspaces = screen.get_workspaces ();

			foreach (var child in get_children ()) {
				unowned IconGroup icon_group = (IconGroup) child;

				// we don't use meta_workspace_index() here because it crashes
				// the wm if the workspace has already been removed. This could
				// happen here if two workspaces are removed very shortly after
				// each other and a transition is still playing. Also, 
				// meta_workspace_index() does the exact same thing.
				var index = existing_workspaces.index (icon_group.workspace);

				if (index < 0)
					child.visible = false;
				else
					child.x = index * (child.width + SPACING);
			}
		}

		public void add_group (IconGroup group)
		{
			add_child (group);

			update_positions ();
		}

		public void remove_group (IconGroup group)
		{
			remove_child (group);

			update_positions ();
		}
	}
}

