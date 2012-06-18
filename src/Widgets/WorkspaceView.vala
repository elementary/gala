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
		Gala.Plugin plugin;
		
		internal Clutter.Actor workspaces;
		Clutter.CairoTexture bg;
		
		bool animating; // delay closing the popup
		
		Gdk.Pixbuf background_pix;
		Clutter.CairoTexture workspace_thumb;
		internal Clutter.CairoTexture scroll;
		
		public WorkspaceView (Gala.Plugin _plugin)
		{
			plugin = _plugin;
			
			height = 140;
			opacity = 0;
			reactive = true;
			
			workspaces = new Clutter.Actor ();
			workspaces.layout_manager = new Clutter.BoxLayout ();
			(workspaces.layout_manager as Clutter.BoxLayout).spacing = 12;
			
			bg = new Clutter.CairoTexture (500, (uint)height);
			bg.auto_resize = true;
			bg.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.WIDTH, 0));
			bg.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.HEIGHT, 0));
			bg.draw.connect (draw_background);
			
			scroll = new Clutter.CairoTexture (100, 12);
			scroll.height = 12;
			scroll.auto_resize = true;
			scroll.draw.connect (draw_scroll);
			
			//setup the the wallpaper thumb
			int width, height;
			var area = plugin.get_screen ().get_monitor_geometry (plugin.get_screen ().get_primary_monitor ());
			width = area.width;
			height = area.height;
			
			workspace_thumb = new Clutter.CairoTexture (120, 120);
			workspace_thumb.height = 80;
			workspace_thumb.width  = (workspace_thumb.height / height) * width;
			workspace_thumb.auto_resize = true;
			workspace_thumb.draw.connect (draw_workspace_thumb);
			
			var settings = new GLib.Settings ("org.gnome.desktop.background");
			
			settings.changed.connect ((key) => {
				if (key == "picture-uri") {
					var path = File.new_for_uri (settings.get_string ("picture-uri")).get_path ();
					try {
						background_pix = new Gdk.Pixbuf.from_file (path).scale_simple 
						((int)workspace_thumb.width, (int)workspace_thumb.height, Gdk.InterpType.HYPER);
					} catch (Error e) { warning (e.message); }
				}
			});
			
			var path = File.new_for_uri (settings.get_string ("picture-uri")).get_path ();
			try {
				background_pix = new Gdk.Pixbuf.from_file (path).scale_simple 
				((int)workspace_thumb.width, (int)workspace_thumb.height, Gdk.InterpType.HYPER);
			} catch (Error e) { warning (e.message); }
			
			
			
			add_child (workspace_thumb);
			add_child (bg);
			add_child (workspaces);
			add_child (scroll);
			
			workspace_thumb.visible = false; //will only be used for cloning
		}
		
		bool draw_workspace_thumb (Cairo.Context cr)
		{
			cr.rectangle (0, 0, workspace_thumb.width, workspace_thumb.height);
			Gdk.cairo_set_source_pixbuf (cr, background_pix, 0, 0);
			cr.fill_preserve ();
			
			cr.set_line_width (1);
			cr.set_source_rgba (0, 0, 0, 1);
			cr.stroke_preserve ();
			
			return false;
		}
		
		bool draw_scroll (Cairo.Context cr)
		{
			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 4, 4, scroll.width-32, 4, 2);
			cr.set_source_rgba (1, 1, 1, 0.8);
			cr.fill ();
			
			return false;
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
		
		/*fade current current workspace out, fade new current workspace in*/
		WorkspaceThumb? current_active = null;
		internal void set_active (int workspace)
		{
			if (current_active != null)
				current_active.indicator.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity : 0);
			current_active = (workspaces.get_child_at_index (workspace) as WorkspaceThumb);
			if (current_active != null)
				current_active.indicator.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity : 255);
		}
		
		void switch_to_next_workspace (bool reverse)
		{
			var screen = plugin.get_screen ();
			var display = screen.get_display ();
			
			var idx = screen.get_active_workspace_index () + (reverse ? -1 : 1);
			
			if (idx < 0 || idx >= screen.n_workspaces)
				return;
			
			screen.get_workspace_by_index (idx).activate (display.get_current_time ());
			if (workspaces.get_n_children () > 0)
				set_active (idx);
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
				&& workspaces.width + workspaces.x > width) { //left
				workspaces.x -= scroll_speed;
			} else if ((event.direction == Clutter.ScrollDirection.UP || event.direction == Clutter.ScrollDirection.LEFT)
				&& workspaces.x < 0) { //right
				workspaces.x += scroll_speed;
			}
			scroll.x = Math.fabsf (width/workspaces.width*workspaces.x);
			
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
			
			/*get the workspaces together*/
			workspaces.get_children ().foreach ((c) => c.destroy () );
			workspaces.remove_all_children ();
			
			for (var i = 0; i < screen.n_workspaces; i++) {
				var space = screen.get_workspace_by_index (i);
				
				var group = new WorkspaceThumb (space, workspace_thumb);
				group.opened.connect (hide);
				group.closed.connect (() => {
					Timeout.add (250, () => { //give the windows time to close
						screen.remove_workspace (space, screen.get_display ().get_current_time ());
						
						scroll.visible = workspaces.width > width;
						if (scroll.visible) {
							if (workspaces.x + workspaces.width < width)
								workspaces.x = width - workspaces.width;
							scroll.width = width/workspaces.width*width;
						} else {
							workspaces.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, x:width / 2 - workspaces.width / 2);
						}
						set_active (screen.get_active_workspace ().index ());
						
						return false;
					});
				});
				
				workspaces.add_child (group);
			}
			
			workspaces.x = width / 2 - workspaces.width / 2;
			workspaces.y = 15;
			
			scroll.visible = workspaces.width > width;
			if (scroll.visible) {
				scroll.y = height - 12;
				scroll.x = 0.0f;
				scroll.width = width/workspaces.width*width;
				workspaces.x = 4.0f;
			}
			
			animating = true;
			Timeout.add (50, () => {
				animating = false;
				return false;
			}); //catch hot corner hiding problem and indicator placement
			
			visible = true;
			grab_key_focus ();
			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, y : area.height - height, opacity : 255);
			set_active (screen.get_active_workspace ().index ());
		}
		
		public new void hide ()
		{
			if (!visible || animating)
				return;
			
			current_active = null;
			
			float width, height;
			plugin.get_screen ().get_size (out width, out height);
			
			plugin.end_modal ();
			plugin.update_input_area ();
			
			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 500, y : height)
				.completed.connect ( () => {
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
