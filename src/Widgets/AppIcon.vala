//
//  Copyright (C) 2012 Tom Beckmann
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
	public class AppIcon : GtkClutter.Texture
	{
		const string DRAG_ACTION = "drag";

		Window window;
		Bamf.Application app;

		public AppIcon (Window _window, Bamf.Application _app)
		{
			window = _window;
			app = _app;

			try {
				set_from_pixbuf (Utils.get_icon_for_window (window, WorkspaceThumb.APP_ICON_SIZE));
			} catch (Error e) { warning (e.message); }

			var action = new DragDropAction (DragDropActionType.SOURCE, WorkspaceThumb.DRAG_ID);
			action.drag_begin.connect (drag_begin);
			action.drag_end.connect (drag_end);
			action.drag_canceled.connect (drag_canceled);

			add_action_with_name (DRAG_ACTION, action);
			reactive = true;
		}

		void drag_canceled ()
		{
			var action = get_action (DRAG_ACTION) as DragDropAction;

			float ax, ay;
			get_transformed_position (out ax, out ay);
			action.handle.animate (AnimationMode.EASE_OUT_BOUNCE, 250, x:ax, y:ay).
				completed.connect (() => {
				action.handle.destroy ();
				opacity = 255;
			});
		}

		void drag_end (Actor destination)
		{
			var action = get_action (DRAG_ACTION) as DragDropAction;
			action.handle.destroy ();

			WorkspaceThumb old = get_parent ().get_parent () as WorkspaceThumb;
			get_parent ().remove_child (this);
			opacity = 255;

			var dest_thumb = destination as WorkspaceThumb;
			var icons = dest_thumb.icons;
			var wallpaper = dest_thumb.wallpaper;

			icons.add_child (this);

			// get all the windows that belong to this app, if possible
			if (app != null && app.get_xids ().length > 1) {
				var wins = window.get_workspace ().list_windows ();
				var xids = app.get_xids ();
				for (var i = 0; i < xids.length; i++) {
					foreach (var win in wins) {
						if (xids.index (i) == (uint32)win.get_xwindow ())
							win.change_workspace (dest_thumb.workspace);
					}
				}
			} else
				window.change_workspace (dest_thumb.workspace);

			if (old != null)
				old.icons.animate (AnimationMode.LINEAR, 100, x:Math.floorf (old.wallpaper.x + old.wallpaper.width / 2 - old.icons.width / 2));
			icons.animate (AnimationMode.LINEAR, 100, x:Math.floorf (wallpaper.x + wallpaper.width / 2 - icons.width / 2));
		}

		Clutter.Actor drag_begin ()
		{
			opacity = 0;

			var handle = new Clone (this);

			get_stage ().add_child (handle);
			return handle;
		}

	}
}
