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
		
		Clutter.Actor workspaces;
		Clutter.CairoTexture bg;
		
		GtkClutter.Texture tile;
		
		bool animating; // delay closing the popup
		
		Gdk.Pixbuf background_pix;
		Clutter.CairoTexture workspace_thumb;
		Clutter.CairoTexture current_workspace;
		Clutter.CairoTexture scroll;
		
		const int current_border = 5;
		
		int _workspace;
		int workspace {
			get {
				return _workspace;
			}
			set {
				if (_workspace == value)
					return;
				
				_workspace = value;
				
				current_workspace.animate (Clutter.AnimationMode.EASE_IN_OUT_SINE, 400,
					x : workspaces.x + workspaces.get_children ().nth_data (_workspace).x - current_border);
			}
		}
		
		const string CURRENT_WORKSPACE_STYLE = """
		* {
			border-style: solid;
			border-width: 1px 1px 1px 1px;
			-unico-inner-stroke-width: 1px 0 1px 0;
			border-radius: 8px;
			
			background-image: -gtk-gradient (linear,
							left top,
							left bottom,
							from (shade (@selected_bg_color, 1.4)),
							to (shade (@selected_bg_color, 0.98)));
			
			-unico-border-gradient: -gtk-gradient (linear,
							left top, left bottom,
							from (alpha (#000, 0.5)),
							to (alpha (#000, 0.6)));
			
			-unico-inner-stroke-gradient: -gtk-gradient (linear,
							left top, left bottom,
							from (alpha (#fff, 0.90)),
							to (alpha (#fff, 0.06)));
		}
		""";
		Gtk.Menu current_workspace_style; //dummy item for drawing
		
		public WorkspaceView (Gala.Plugin _plugin)
		{
			plugin = _plugin;
			
			height = 128;
			opacity = 0;
			reactive = true;
			
			workspaces = new Clutter.Actor ();
			var box_layout = new Clutter.BoxLayout ();
			workspaces.set_layout_manager (box_layout);
			
			box_layout.spacing = 12;
			
			bg = new Clutter.CairoTexture (500, (uint)height);
			bg.auto_resize = true;
			bg.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.WIDTH, 0));
			bg.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.HEIGHT, 0));
			bg.draw.connect (draw_background);
			
			scroll = new Clutter.CairoTexture (100, 12);
			scroll.height = 12;
			scroll.auto_resize = true;
			scroll.draw.connect (draw_scroll);
			
			leave_event.connect ((e) => {
				if (!contains (e.related))
					hide ();
				
				return false;
			});
			
			tile = new GtkClutter.Texture ();
			try {
				tile.set_from_pixbuf (Gtk.IconTheme.get_default ().load_icon ("preferences-desktop-display", 64, 0));
			} catch (Error e) {
				warning (e.message);
			}
			
			tile.reactive = true;
			tile.button_release_event.connect (() => {
				var screen = plugin.get_screen ();
				
				var windows = new GLib.List<Window> ();
				screen.get_active_workspace ().list_windows ().foreach ( (w) => {
					if (w.window_type != Meta.WindowType.NORMAL || w.minimized)
						return;
					
					windows.append (w);
				});
				
				//make sure active window is biggest
				var active_idx = windows.index (screen.get_display ().get_focus_window ());
				if (active_idx != -1 && active_idx != 0) {
					windows.delete_link (windows.nth (active_idx));
					windows.prepend (screen.get_display ().get_focus_window ());
				}
				
				var area = screen.get_monitor_geometry (screen.get_primary_monitor ());
				var n_wins = windows.length ();
				var index  = 0;
				
				windows.foreach ( (w) => {
					if (w.maximized_horizontally || w.maximized_vertically)
						w.unmaximize (Meta.MaximizeFlags.VERTICAL | Meta.MaximizeFlags.HORIZONTAL);
					
					switch (n_wins) {
						case 1:
							w.move_resize_frame (true, area.x, area.y, area.width, area.height);
							break;
						case 2:
							w.move_resize_frame (true, area.x+area.width/2*index, area.y, area.width/2, 
								area.height);
							break;
						case 3:
							if (index == 0)
								w.move_resize_frame (true, area.x, area.y, area.width/2, area.height);
							else {
								w.move_resize_frame (true, area.x+area.width/2, 
									area.y+(area.height/2*(index-1)), area.width/2, area.height/2);
							}
							break;
						case 4:
							if (index < 2)
								w.move_resize_frame (true, area.x+area.width/2*index, area.y, 
									area.width/2, area.height/2);
							else
								w.move_resize_frame (true, (index==3)?area.x+area.width/2:area.x, 
									area.y+area.height/2, area.width/2, area.height/2);
							break;
						case 5:
							if (index < 2)
								w.move_resize_frame (true, area.x, area.y+(area.height/2*index), 
									area.width/2, area.height/2);
							else
								w.move_resize_frame (true, area.x+area.width/2, 
									area.y+(area.height/3*(index-2)), area.width/2, area.height/3);
							break;
						case 6:
							if (index < 3)
								w.move_resize_frame (true, area.x, area.y+(area.height/3*index),
									area.width/2, area.height/3);
							else
								w.move_resize_frame (true, area.x+area.width/2, 
									area.y+(area.height/3*(index-3)), area.width/2, area.height/3);
							break;
						default:
							return;
					}
					index ++;
				});
				return true;
			});
			
			int width, height;
			var area = plugin.get_screen ().get_monitor_geometry (plugin.get_screen ().get_primary_monitor ());
			width = area.width;
			height = area.height;
			
			workspace_thumb = new Clutter.CairoTexture (120, 120);
			workspace_thumb.height = 80;
			workspace_thumb.width  = (workspace_thumb.height / height) * width;
			workspace_thumb.auto_resize = true;
			workspace_thumb.draw.connect (draw_workspace_thumb);
			
			current_workspace_style = new Gtk.Menu ();
			var provider = new Gtk.CssProvider ();
			try {
				provider.load_from_data (CURRENT_WORKSPACE_STYLE, -1);
			} catch (Error e) { warning (e.message); }
			current_workspace_style.get_style_context ().add_provider (provider, 20000);
			
			current_workspace = new Clutter.CairoTexture (120, 120);
			current_workspace.height = workspace_thumb.height + current_border*2;
			current_workspace.width  = workspace_thumb.width  + current_border*2;
			current_workspace.auto_resize = true;
			current_workspace.draw.connect (draw_current_workspace);
			
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
			/*add_child (tile); removed for now until Luna+1 */
			add_child (current_workspace);
			add_child (workspaces);
			add_child (scroll);
			
			workspace_thumb.visible = false; //will only be used for cloning
		}
		
		bool draw_current_workspace (Cairo.Context cr)
		{
			current_workspace_style.get_style_context ().render_activity (cr, 0, 0, 
				current_workspace.width, current_workspace.height);
			
			return false;
		}
		
		bool draw_workspace_thumb (Cairo.Context cr)
		{
			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 0, 0, 
				workspace_thumb.width, workspace_thumb.height, 5);
			Gdk.cairo_set_source_pixbuf (cr, background_pix, 0, 0);
			cr.fill_preserve ();
			
			cr.set_line_width (1);
			cr.set_source_rgba (0, 0, 0, 1);
			cr.stroke_preserve ();
			
			return false;
		}
		
		bool draw_scroll (Cairo.Context cr)
		{
			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 4, 4, scroll.width-32-current_border, 4, 2);
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
		
		void switch_to_next_workspace (bool reverse, bool reposition = true)
		{
			var screen = plugin.get_screen ();
			var display = screen.get_display ();
			
			var idx = screen.get_active_workspace_index () + (reverse ? -1 : 1);
			
			if (idx < 0 || idx >= screen.n_workspaces)
				return;
			
			screen.get_workspace_by_index (idx).activate (display.get_current_time ());
			if (reposition)
				workspace = idx;
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
			if (event.keyval == Clutter.Key.Alt_L) {
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
				current_workspace.x -= scroll_speed;
			} else if ((event.direction == Clutter.ScrollDirection.UP || event.direction == Clutter.ScrollDirection.LEFT)
				&& workspaces.x < 0) { //right
				workspaces.x += scroll_speed;
				current_workspace.x += scroll_speed;
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
			
			animating = true;
			
			var area = screen.get_monitor_geometry (screen.get_primary_monitor ());
			
			tile.x = area.width  - 80;
			tile.y = 120;
			
			y = area.height;
			width = area.width;
			
			/*get the workspaces together*/
			workspaces.remove_all_children ();
			
			for (var i = 0; i < screen.n_workspaces; i++) {
				var space = screen.get_workspace_by_index (i);
				
				var group = new Clutter.Actor ();
				var icons = new Clutter.Actor ();
				icons.set_layout_manager (new Clutter.BoxLayout ());
				var backg = new Clutter.Clone (workspace_thumb);
				
				var close = new GtkClutter.Texture ();
				try {
					close.set_from_pixbuf (Granite.Widgets.get_close_pixbuf ());
				} catch (Error e) { warning (e.message); }
				
				var shown_applications = new List<Bamf.Application> ();
				
				space.list_windows ().foreach ((w) => {
					if (w.window_type != Meta.WindowType.NORMAL || w.minimized)
						return;
					
					var app = Bamf.Matcher.get_default ().get_application_for_xid ((uint32)w.get_xwindow ());
					if (shown_applications.index (app) != -1)
						return;
					
					if (app != null)
						shown_applications.append (app);
					
					var pix = Gala.Plugin.get_icon_for_window (w, 32);
					var icon = new GtkClutter.Texture ();
					try {
						icon.set_from_pixbuf (pix);
					} catch (Error e) { warning (e.message); }
					
					icon.reactive = true;
					icon.button_release_event.connect ( () => {
						space.activate_with_focus (w, screen.get_display ().get_current_time ());
						hide ();
						return false;
					});
					
					icons.add_child (icon);
				});
				
				group.add_child (backg);
				group.add_child (icons);
				
				icons.y = backg.height - 16;
				icons.x = group.width / 2 - icons.width / 2;
				(icons.layout_manager as Clutter.BoxLayout).spacing = 6;
				
				group.height = 160;
				
				if (space.index () != screen.n_workspaces - 1) {//dont allow closing the last one
					group.add_child (close);
				}
				
				close.x = -12.0f;
				close.y = -10.0f;
				close.reactive = true;
				close.scale_gravity = Clutter.Gravity.CENTER;
				close.scale_x = 0;
				close.scale_y = 0;
				
				close.button_release_event.connect (() => {
					space.list_windows ().foreach ((w) => {
						if (w.window_type != WindowType.DOCK) {
							var gw = Gdk.X11Window.foreign_new_for_display (Gdk.Display.get_default (), 
								w.get_xwindow ());
							if (gw != null)
								gw.destroy ();
						}
					});
					Timeout.add (250, () => { //give the windows time to close
						screen.remove_workspace (space, screen.get_display ().get_current_time ());
						workspace = screen.get_active_workspace ().index ();
						return false;
					});
					
					group.animate (Clutter.AnimationMode.EASE_IN_QUAD, 250, width:0.0f, opacity:0).completed.connect (() => {
						workspaces.remove_child (group);
					});
					
					return true;
				});
				
				if (space.index () == screen.n_workspaces - 1) { //give the last one a different style
					group.opacity = 127;
					
					var plus = new GtkClutter.Texture ();
					try {
						var pix = Gtk.IconTheme.get_default ().choose_icon ({"list-add-symbolic", "list-add"}, 32, 0).
							load_symbolic ({1, 1, 1, 1});
						plus.set_from_pixbuf (pix);
					} catch (Error e) { warning (e.message); }
					
					plus.x = group.width / 2 - plus.width / 2;
					plus.y = (backg.x + backg.height) / 2 - plus.height / 2;
					
					group.add_child (plus);
				}
				
				bool hovering = false;
				group.reactive = true;
				group.button_release_event.connect (() => {
					space.activate (plugin.get_screen ().get_display ().get_current_time ());
					workspace = plugin.get_screen ().get_active_workspace ().index ();
					hide ();
					return true;
				});
				group.enter_event.connect (() => {
					Timeout.add (500, () => {
						close.visible = true;
						if (hovering)
							close.animate (Clutter.AnimationMode.EASE_OUT_ELASTIC, 400, scale_x:1.0f, scale_y:1.0f);
						return false;
					});
					
					if (space.index () == screen.n_workspaces - 1)
						group.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 300, opacity:210);
					
					hovering = true;
					
					return true;
				});
				group.leave_event.connect ((e) => {
					if (group.contains (e.related) || screen.get_workspaces ().index (space) < 0)
						return false;
					
					close.animate (Clutter.AnimationMode.EASE_IN_QUAD, 400, scale_x:0.0f, scale_y:0.0f)
						.completed.connect (() => close.visible = false );
					
					hovering = false;
					
					if (space.index () == screen.n_workspaces - 1)
						group.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, opacity:127);
					return false;
				});
				
				workspaces.add_child (group);
			}
			
			var new_idx = screen.get_active_workspace ().index ();
			
			workspaces.x = width / 2 - workspaces.width / 2;
			workspaces.y = 20;
			
			current_workspace.y = workspaces.y - current_border;
			
			scroll.y = height - 12;
			
			visible = true;
			grab_key_focus ();
			Timeout.add (50, () => {
				
				current_workspace.x = workspaces.x + workspaces.get_children ().nth_data (new_idx).x - current_border;
				workspace = new_idx;
				animating = false;
				return false;
			}); //catch hot corner hiding problem and indicator placement
			
			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, y : area.height - height, opacity : 255);
			
			scroll.visible = workspaces.width > width;
			if (scroll.visible) {
				scroll.x = 0.0f;
				scroll.width = width/workspaces.width*width;
				workspaces.x = 4.0f + current_border;
			}
		}
		
		public new void hide ()
		{
			if (!visible || animating)
				return;
			
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
			switch_to_next_workspace (left, false);
			
			show ();
		}
	}
}
