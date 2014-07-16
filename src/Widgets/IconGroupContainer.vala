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
	public class WorkspaceInsertThumb : Actor
	{
		public int workspace_index { get; construct set; }

		public WorkspaceInsertThumb (int workspace_index)
		{
			Object (workspace_index: workspace_index);

			width = IconGroupContainer.SPACING;
			height = IconGroupContainer.SPACING;
			y = (IconGroupContainer.GROUP_WIDTH - IconGroupContainer.SPACING) / 2;
			opacity = 0;
			set_pivot_point (0.5f, 0.5f);
			reactive = true;

			layout_manager = new BinLayout (BinAlignment.CENTER, BinAlignment.CENTER);

			var drop = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
			drop.crossed.connect ((hovered) => {
				save_easing_state ();
				set_easing_duration (200);

				if (!hovered) {
					remove_transition ("pulse");
					opacity = 0;
					width = IconGroupContainer.SPACING;
				} else {
					add_pulse_animation ();
					opacity = 200;
					width = IconGroupContainer.SPACING + 64;
				}

				restore_easing_state ();
			});

			add_action (drop);
		}

		public void set_window_thumb (Window window)
		{
			destroy_all_children ();

			var icon = new Utils.WindowIcon (window, IconGroupContainer.SPACING);
			icon.x_align = ActorAlign.CENTER;
			add_child (icon);
		}

		void add_pulse_animation ()
		{
			var transition = new TransitionGroup ();
			transition.duration = 800;
			transition.auto_reverse = true;
			transition.repeat_count = -1;
			transition.progress_mode = AnimationMode.LINEAR;

			var scale_x_transition = new PropertyTransition ("scale-x");
			scale_x_transition.set_from_value (0.8);
			scale_x_transition.set_to_value (1.1);
			scale_x_transition.auto_reverse = true;

			var scale_y_transition = new PropertyTransition ("scale-y");
			scale_y_transition.set_from_value (0.8);
			scale_y_transition.set_to_value (1.1);
			scale_y_transition.auto_reverse = true;

			transition.add_transition (scale_x_transition);
			transition.add_transition (scale_y_transition);

			add_transition ("pulse", transition);
		}
	}

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

			layout_manager = new BoxLayout ();

			Prefs.add_listener ((pref) => {
				if (pref != Preference.DYNAMIC_WORKSPACES)
					return;

				if (!Prefs.get_dynamic_workspaces ()) {
					foreach (var child in get_children ()) {
						if (child is WorkspaceInsertThumb)
							child.destroy ();
					}
				} else {
					// TODO insert WorkspaceInsertThumbs everywhere
				}
			});
		}

		void update_positions ()
		{
			/*unowned List<Workspace> existing_workspaces = screen.get_workspaces ();

			var current_inserter_index = 0;

			foreach (var child in get_children ()) {
				if (child is IconGroup) {
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
						child.x = index * (GROUP_WIDTH + SPACING);
				} else {
					child.x = -SPACING + current_inserter_index * (GROUP_WIDTH + SPACING);
					((WorkspaceInsertThumb) child).current_index = current_inserter_index++;
				}
			}*/
		}

		public void add_group (IconGroup group)
		{
			var index = group.workspace.index ();

			insert_child_at_index (group, index * 2);

			if (Prefs.get_dynamic_workspaces ())
				insert_child_at_index (new WorkspaceInsertThumb (index), index * 2);

			update_inserter_indices ();
		}

		public void remove_group (IconGroup group)
		{
			if (Prefs.get_dynamic_workspaces ())
				remove_child (group.get_previous_sibling ());

			remove_child (group);

			update_inserter_indices ();
		}

		void update_inserter_indices ()
		{
			var current_index = 0;

			foreach (var child in get_children ()) {
				unowned WorkspaceInsertThumb thumb = child as WorkspaceInsertThumb;
				if (thumb != null) {
					thumb.workspace_index = current_index++;
				}
			}
		}
	}
}

