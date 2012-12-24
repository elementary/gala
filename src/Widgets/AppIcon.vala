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
		
		Window window;
		Bamf.Application app;
		
		public AppIcon (Window _window, Bamf.Application _app)
		{
			window = _window;
			app = _app;
			
			try {
				set_from_pixbuf (Utils.get_icon_for_window (window, WorkspaceThumb.APP_ICON_SIZE));
			} catch (Error e) { warning (e.message); }
			
			var action = new DragAction ();
			action.drag_begin.connect (drag_begin);
			action.drag_end.connect (drag_end);
			
			add_action_with_name ("drag", action);
			reactive = true;
		}
		
		void drag_end (Actor actor, float x, float y, ModifierType modifier)
		{
			var action = actor.get_action ("drag") as DragAction;
			Actor handle = null;
			if (action != null)
				handle = action.drag_handle;
			if (WorkspaceThumb.destination == null) {
				float ax, ay;
				actor.get_parent ().animate (AnimationMode.LINEAR, 150, opacity:255);
				actor.get_transformed_position (out ax, out ay);
				handle.animate (AnimationMode.EASE_OUT_BOUNCE, 250, x:ax, y:ay)
					.completed.connect (() => {
					if (handle != null)
						handle.destroy ();
					actor.opacity = 255;
				});
			} else {
				WorkspaceThumb old = actor.get_parent ().get_parent () as WorkspaceThumb;
				actor.get_parent ().remove_child (actor);
				actor.opacity = 255;
				
				var icons = (WorkspaceThumb.destination as WorkspaceThumb).icons;
				var wallpaper = (WorkspaceThumb.destination as WorkspaceThumb).wallpaper;
				
				icons.add_child (actor);

				// get all the windows that belong to this app, if possible
				if (app != null && app.get_xids ().length > 1) {
					var wins = window.get_workspace ().list_windows ();
					var xids = app.get_xids ();
					for (var i = 0; i < xids.length; i++) {
						foreach (var win in wins) {
							if (xids.index (i) == (uint32)win.get_xwindow ())
								win.change_workspace ((WorkspaceThumb.destination as WorkspaceThumb).workspace);
						}
					}
				} else
					window.change_workspace ((WorkspaceThumb.destination as WorkspaceThumb).workspace);
				
				if (handle != null)
					handle.destroy ();
				
				if (old != null)
					old.icons.animate (AnimationMode.LINEAR, 100, x:Math.floorf (old.wallpaper.x + old.wallpaper.width / 2 - old.icons.width / 2));
				icons.animate (AnimationMode.LINEAR, 100, x:Math.floorf (wallpaper.x + wallpaper.width / 2 - icons.width / 2));
			}

			WorkspaceThumb.destination = null;
		}
		
		void drag_begin (Actor actor, float x, float y, ModifierType modifier)
		{
			actor.opacity = 0;
			
			float ax, ay;
			actor.get_transformed_position (out ax, out ay);
			
			var handle = new Clone (actor);
			handle.set_position (ax, ay);
			
			Compositor.get_stage_for_screen (window.get_screen ()).add_child (handle);
			WorkspaceThumb.destination = null;
			(actor.get_action ("drag") as DragAction).drag_handle = handle;
		}
		
	}
}
