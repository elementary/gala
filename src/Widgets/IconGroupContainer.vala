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
		const int PLUS_SIZE = 8;
		const int PLUS_WIDTH = 24;

		public int current_index { get; set; default = 0; }

		public WorkspaceInsertThumb ()
		{
			width = IconGroupContainer.SPACING;
			height = IconGroupContainer.SPACING;
			y = (IconGroupContainer.GROUP_WIDTH - IconGroupContainer.SPACING) / 2;
			opacity = 0;
			set_pivot_point (0.5f, 0.5f);
			reactive = true;

			var canvas = new Canvas ();
			canvas.draw.connect (draw_plus);
			canvas.set_size (IconGroupContainer.SPACING, IconGroupContainer.SPACING);
			content = canvas;

			var drop = new DragDropAction (DragDropActionType.DESTINATION, "multitaskingview-window");
			drop.crossed.connect ((hovered) => {
				save_easing_state ();
				set_easing_duration (200);

				if (!hovered) {
					remove_transition ("pulse");
					opacity = 0;
				} else {
					add_pulse_animation ();
					opacity = 200;
				}

				restore_easing_state ();
			});

			add_action (drop);
		}

		bool draw_plus (Cairo.Context cr)
		{
			cr.set_operator (Cairo.Operator.CLEAR);
			cr.paint ();
			cr.set_operator (Cairo.Operator.OVER);

			var size = IconGroupContainer.SPACING;
			var buffer = new Granite.Drawing.BufferSurface (size, size);
			var offset = size / 2 - PLUS_WIDTH / 2;

			buffer.context.rectangle (PLUS_WIDTH / 2 - PLUS_SIZE / 2 + 0.5 + offset,
				0.5 + offset,
				PLUS_SIZE - 1,
				PLUS_WIDTH - 1);

			buffer.context.rectangle (0.5 + offset,
				PLUS_WIDTH / 2 - PLUS_SIZE / 2 + 0.5 + offset,
				PLUS_WIDTH - 1,
				PLUS_SIZE - 1);

			buffer.context.set_source_rgb (0, 0, 0);
			buffer.context.fill_preserve ();
			buffer.exponential_blur (5);

			buffer.context.set_source_rgb (1, 1, 1);
			buffer.context.set_line_width (1);
			buffer.context.stroke_preserve ();

			buffer.context.set_source_rgb (0.8, 0.8, 0.8);
			buffer.context.fill ();

			cr.set_source_surface (buffer.surface, 0, 0);
			cr.paint ();

			return false;
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
		}

		void update_positions ()
		{
			unowned List<Workspace> existing_workspaces = screen.get_workspaces ();

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
			}
		}

		public void add_group (IconGroup group)
		{
			add_child (group);

			if (Prefs.get_dynamic_workspaces ())
				add_child (new WorkspaceInsertThumb ());

			update_positions ();
		}

		public void remove_group (IconGroup group)
		{
			remove_child (group);

			if (Prefs.get_dynamic_workspaces ()) {
				// find some WorkspaceInsertThumb to remove, update_positions orders
				// them differently anyway, so position doesn't matter here
				foreach (var child in get_children ()) {
					if (child is WorkspaceInsertThumb) {
						remove_child (child);
						break;
					}
				}
			}

			update_positions ();
		}
	}
}

