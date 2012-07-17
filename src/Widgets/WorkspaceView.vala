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
		Screen screen;
		
		Clutter.Actor thumbnails;
		Clutter.CairoTexture background;
		Clutter.CairoTexture scroll;
		Clutter.Actor click_catcher; //invisible plane that catches clicks outside the view
		
		bool animating; // delay closing the popup
		
		uint timeout = 0;
		
		bool wait_one_key_release; //called by shortcut, don't close it on first keyrelease
		
		public WorkspaceView (Gala.Plugin _plugin)
		{
			plugin = _plugin;
			screen = plugin.get_screen ();
			
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
			
			click_catcher = new Clutter.Actor ();
			click_catcher.reactive = true;
			click_catcher.button_release_event.connect ((e) => {
				hide ();
				return true;
			});
			Compositor.get_stage_for_screen (screen).add_child (click_catcher);
			
			add_child (background);
			add_child (thumbnails);
			add_child (scroll);
			
			screen.workareas_changed.connect (initial_configuration);
		}
		
		//method that waits for the workspaces to be configured on first run
		void initial_configuration ()
		{
			screen.workareas_changed.disconnect (initial_configuration);
			
			//remove everything except for the first
			for (var i=1;i<screen.get_workspaces ().length ();i++) {
				screen.remove_workspace (screen.get_workspaces ().nth_data (i), screen.get_display ().get_current_time ());
			}
			
			var thumb = new WorkspaceThumb (screen.get_workspaces ().nth_data (0));
			thumb.clicked.connect (hide);
			thumb.closed.connect (remove_workspace);
			thumb.window_on_last.connect (add_workspace);
			
			thumbnails.add_child (thumb);
			
			//do a second run if necessary
			if (screen.n_workspaces != 1) {
				for (var i=1;i<screen.get_workspaces ().length ();i++) {
					screen.remove_workspace (screen.get_workspaces ().nth_data (i), screen.get_display ().get_current_time ());
				}
			}
			
			add_workspace ();
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
			
			thumb.show ();
			
			check_scrollbar ();
		}
		
		void remove_workspace (WorkspaceThumb thumb)
		{
			thumb.clicked.disconnect (hide);
			thumb.closed.disconnect (remove_workspace);
			thumb.window_on_last.disconnect (add_workspace);
			
			var workspace = thumb.workspace;
			
			if (workspace != null && workspace.index () > -1) { //dont remove non existing workspaces
				var screen = workspace.get_screen ();
				screen.remove_workspace (workspace, screen.get_display ().get_current_time ());
			}
			
			thumb.workspace = null;
			
			thumbnails.remove_child (thumb);
			thumb.destroy ();
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
			
			var neighbor = screen.get_active_workspace ().get_neighbor (reverse ? MotionDirection.LEFT : MotionDirection.RIGHT);
			
			if (neighbor == null)
				return;
			
			neighbor.activate (display.get_current_time ());
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
					if ((event.modifier_state & Clutter.ModifierType.SHIFT_MASK) == 1)
						plugin.move_window (screen.get_display ().get_focus_window (), true);
					else
						switch_to_next_workspace (true);
					return false;
				case Clutter.Key.Right:
					if ((event.modifier_state & Clutter.ModifierType.SHIFT_MASK) == 1)
						plugin.move_window (screen.get_display ().get_focus_window (), false);
					else
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
				event.keyval == Clutter.Key.Control_L || 
				event.keyval == Clutter.Key.Alt_R || 
				event.keyval == Clutter.Key.Super_R || 
				event.keyval == Clutter.Key.Control_R) {
				
				if (wait_one_key_release)
					return false;
				
				hide ();
				if (timeout != 0) {
					Source.remove (timeout);
					timeout = 0;
				}
				
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
		
		/*
		 * if wait, wait one second and look if super is still pressed, if so show
		 * if shortcut, wait one key release before closing
		 */
		public new void show (bool wait=false, bool shortcut=false)
		{
			if (visible)
				return;
			
			wait_one_key_release = shortcut;
			
			var screen = plugin.get_screen ();
			
			Utils.set_input_area (screen, Utils.InputArea.FULLSCREEN);
			plugin.begin_modal ();
			
			visible = true;
			grab_key_focus ();
			
			if (wait) {
				timeout = Timeout.add (1000, () => {
					show_elements ();
					timeout = 0;
					return false;
				});
			} else
				show_elements ();
		}
		
		void show_elements ()
		{
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
			
			click_catcher.width = width;
			click_catcher.height = area.height - height;
			click_catcher.x = 0;
			click_catcher.y = 0;
			
			animating = true;
			Timeout.add (50, () => {
				animating = false;
				return false;
			}); //catch hot corner hiding problem and indicator placement
			
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
			
			show (true);
		}
	}
}
