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
		public const int EXPAND_DELAY = 300;

		public int workspace_index { get; construct set; }
		public bool expanded { get; private set; default = false; }

		uint expand_timeout = 0;

		public WorkspaceInsertThumb (int workspace_index)
		{
			Object (workspace_index: workspace_index);

			width = IconGroupContainer.SPACING;
			height = IconGroupContainer.GROUP_WIDTH;
			y = (IconGroupContainer.GROUP_WIDTH - IconGroupContainer.SPACING) / 2;
			opacity = 0;
			set_pivot_point (0.5f, 0.5f);
			reactive = true;

			layout_manager = new BinLayout (BinAlignment.CENTER);

			var drop = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
			drop.crossed.connect ((hovered) => {
				if (!Prefs.get_dynamic_workspaces ())
					return;

				if (!hovered) {
					if (expand_timeout != 0) {
						Source.remove (expand_timeout);
						expand_timeout = 0;
					}

					transform (false);
				} else
					expand_timeout = Timeout.add (EXPAND_DELAY, expand);
			});

			add_action (drop);
		}

		public void set_window_thumb (Window window)
		{
			destroy_all_children ();

			var icon = new Utils.WindowIcon (window, IconGroupContainer.GROUP_WIDTH);
			icon.x_align = ActorAlign.CENTER;
			add_child (icon);
		}

		bool expand ()
		{
			expand_timeout = 0;

			transform (true);

			return false;
		}

		void transform (bool expand)
		{
			save_easing_state ();
			set_easing_mode (AnimationMode.EASE_OUT_QUAD);
			set_easing_duration (200);

			if (!expand) {
				remove_transition ("pulse");
				opacity = 0;
				width = IconGroupContainer.SPACING;
				expanded = false;
			} else {
				add_pulse_animation ();
				opacity = 200;
				width = IconGroupContainer.GROUP_WIDTH + IconGroupContainer.SPACING * 2;
				expanded = true;
			}

			restore_easing_state ();
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

		public signal void request_reposition ();

		public Screen screen { get; construct; }

		public IconGroupContainer (Screen screen)
		{
			Object (screen: screen);

			layout_manager = new BoxLayout ();
		}

		public void add_group (IconGroup group)
		{
			var index = group.workspace.index ();

			insert_child_at_index (group, index * 2);

			var thumb = new WorkspaceInsertThumb (index);
			thumb.notify["expanded"].connect_after (expanded_changed);
			insert_child_at_index (thumb, index * 2);

			update_inserter_indices ();
		}

		public void remove_group (IconGroup group)
		{
			var thumb = (WorkspaceInsertThumb) group.get_previous_sibling ();
			thumb.notify["expanded"].disconnect (expanded_changed);
			remove_child (thumb);

			remove_child (group);

			update_inserter_indices ();
		}

		void expanded_changed (ParamSpec param)
		{
			request_reposition ();
		}

		/**
		 * Calculates the width that will be occupied taking currently running animations
		 * end states into account
		 */
		public float calculate_total_width ()
		{
			var width = 0.0f;
			foreach (var child in get_children ()) {
				if (child is WorkspaceInsertThumb) {
					if (((WorkspaceInsertThumb) child).expanded)
						width += GROUP_WIDTH + SPACING * 2;
					else
						width += SPACING;
				} else
					width += GROUP_WIDTH;
			}

			width += SPACING;

			return width;
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

