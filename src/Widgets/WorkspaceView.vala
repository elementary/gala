//  
//  Copyright (C) 2012 Tom Beckmann, Rico Tzschichholz
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

using Meta;

namespace Gala
{
	public class WorkspaceView : Clutter.Actor
	{
		static const float VIEW_HEIGHT = 140.0f;
		
		Gala.Plugin plugin;
		
		Clutter.Actor thumbnails;
		Clutter.CairoTexture background;
		
		bool animating; // delay closing the popup
		
		Clutter.CairoTexture scroll;
		
		public WorkspaceView (Gala.Plugin _plugin)
		{
			plugin = _plugin;
			
			height = VIEW_HEIGHT;
			opacity = 0;
			reactive = true;
			
			thumbnails = new Clutter.Actor ();
			thumbnails.layout_manager = new Clutter.BoxLayout ();
			(thumbnails.layout_manager as Clutter.BoxLayout).spacing = 12;
			(thumbnails.layout_manager as Clutter.BoxLayout).homogeneous = true;
			
			background = new Clutter.CairoTexture (500, (uint)height);
			background.auto_resize = true;
			background.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.WIDTH, 0));
			background.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.HEIGHT, 0));
			background.draw.connect (draw_background);
			
			scroll = new Clutter.CairoTexture (100, 12);
			scroll.height = 12;
			scroll.auto_resize = true;
			scroll.draw.connect (draw_scroll);
			
			add_child (background);
			add_child (thumbnails);
			add_child (scroll);
			
			foreach (var wp in plugin.get_screen ().get_workspaces ()) {
				var thumb = new WorkspaceThumb (wp);
				thumb.clicked.connect (hide);
				thumb.closed.connect (remove_workspace);
				thumb.window_on_last.connect (add_workspace);
								
				thumbnails.add_child (thumb);
			}
		}
		
		bool draw_background (Cairo.Context cr)
		{
			cr.rectangle (0, 1, width, height);
			cr.set_source_rgb (0.15, 0.15, 0.15);
			cr.fill ();
			
			cr.move_to (0, 0);
			cr.line_to (width, 0);
			cr.set_line_width (1);
			cr.set_source_rgba (1, 1, 1, 0.5);
			cr.stroke ();
			
			var grad = new Cairo.Pattern.linear (0, 0, 0, 15);
			grad.add_color_stop_rgba (0, 0, 0, 0, 0.4);
			grad.add_color_stop_rgba (1, 0, 0, 0, 0);
			
			cr.rectangle (0, 1, width, 15);
			cr.set_source (grad);
			cr.fill ();
			
			return false;
		}
		
		bool draw_scroll (Cairo.Context cr)
		{
			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 4, 4, scroll.width-32, 4, 2);
			cr.set_source_rgba (1, 1, 1, 0.8);
			cr.fill ();
			
			return false;
		}
		
		void add_workspace ()
		{
			var screen = plugin.get_screen ();
			var wp = screen.append_new_workspace (false, screen.get_display ().get_current_time ());		
			if (wp == null)
				return;
			
			var thumb = new WorkspaceThumb (wp);
			thumb.clicked.connect (hide);
			thumb.closed.connect (remove_workspace);
			thumb.window_on_last.connect (add_workspace);
						
			thumbnails.add_child (thumb);

			check_scrollbar ();
		}
		
		void remove_workspace (WorkspaceThumb thumb)
		{
			thumb.clicked.disconnect (hide);
			thumb.closed.disconnect (remove_workspace);
			thumb.window_on_last.disconnect (add_workspace);
			
			var workspace = thumb.workspace;
			thumb.workspace = null;
			
			var screen = workspace.get_screen ();
			screen.remove_workspace (workspace, screen.get_display ().get_current_time ());
			
			thumbnails.remove_child (thumb);
			
			check_scrollbar ();
		}

		void check_scrollbar ()
		{
			scroll.visible = thumbnails.width > width;
			
			if (scroll.visible) {
				if (thumbnails.x + thumbnails.width < width)
					thumbnails.x = width - thumbnails.width;
				scroll.width = width / thumbnails.width * width;
			} else {
				thumbnails.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, x : width / 2 - thumbnails.width / 2);
			}
		}
		
		void switch_to_next_workspace (bool reverse)
		{
			var screen = plugin.get_screen ();
			var display = screen.get_display ();
			
			var idx = screen.get_active_workspace_index () + (reverse ? -1 : 1);
			
			if (idx < 0 || idx >= screen.n_workspaces)
				return;
			
			screen.get_workspace_by_index (idx).activate (display.get_current_time ());
		}
		
		public override bool leave_event (Clutter.CrossingEvent event) {
			if (!contains (event.related))
				hide ();
			
			return false;
		}
		
		public override bool key_press_event (Clutter.KeyEvent event)
		{
			switch (event.keyval) {
				case Clutter.Key.Left:
					switch_to_next_workspace (true);
					return false;
				case Clutter.Key.Right:
					switch_to_next_workspace (false);
					return false;
				default:
					break;
			}
			
			return true;
		}
		
		public override bool key_release_event (Clutter.KeyEvent event)
		{
			if (event.keyval == Clutter.Key.Alt_L || 
				event.keyval == Clutter.Key.Super_L || 
				event.keyval == Clutter.Key.Control_L) {
				hide ();
				
				return true;
			}
			
			return false;
		}
		
		const float scroll_speed = 30.0f;
		public override bool scroll_event (Clutter.ScrollEvent event)
		{
			if ((event.direction == Clutter.ScrollDirection.DOWN || event.direction == Clutter.ScrollDirection.RIGHT)
				&& thumbnails.width + thumbnails.x > width) { //left
				thumbnails.x -= scroll_speed;
			} else if ((event.direction == Clutter.ScrollDirection.UP || event.direction == Clutter.ScrollDirection.LEFT)
				&& thumbnails.x < 0) { //right
				thumbnails.x += scroll_speed;
			}
			scroll.x = Math.floorf (width / thumbnails.width * thumbnails.x);
			
			return false;
		}
		
		public new void show ()
		{
			if (visible)
				return;
			
			plugin.set_input_area (Gala.InputArea.FULLSCREEN);
			plugin.begin_modal ();
			
			var screen = plugin.get_screen ();
			
			var area = screen.get_monitor_geometry (screen.get_primary_monitor ());
			y = area.height;
			width = area.width;
			
			thumbnails.get_children ().foreach ((thumb) => {
				thumb.show ();
			});
			
			thumbnails.x = width / 2 - thumbnails.width / 2;
			thumbnails.y = 15;
			
			scroll.visible = thumbnails.width > width;
			if (scroll.visible) {
				scroll.y = height - 12;
				scroll.x = 0.0f;
				scroll.width = width / thumbnails.width * width;
				thumbnails.x = 4.0f;
			}
			
			animating = true;
			Timeout.add (50, () => {
				animating = false;
				return false;
			}); //catch hot corner hiding problem and indicator placement
			
			visible = true;
			grab_key_focus ();
			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, y : area.height - height, opacity : 255);
		}
		
		public new void hide ()
		{
			if (!visible || animating)
				return;
			
			float width, height;
			plugin.get_screen ().get_size (out width, out height);
			
			plugin.end_modal ();
			plugin.update_input_area ();
			
			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 500, y : height).completed.connect (() => {
				thumbnails.get_children ().foreach ((thumb) => {
					thumb.hide ();
				});
				visible = false;
			});
		}
		
		public void handle_switch_to_workspace (Meta.Display display, Meta.Screen screen, Meta.Window? window,
			X.Event event, Meta.KeyBinding binding)
		{
			bool left = (binding.get_name () == "switch-to-workspace-left");
			switch_to_next_workspace (left);
			
			show ();
		}
	}
}
