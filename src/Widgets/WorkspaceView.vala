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
		
		int _workspace;
		int workspace {
			get {
				return _workspace;
			}
			set {
				_workspace = value;
				current_workspace.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 300,
					x : workspaces.x - 5 + 
					_workspace *
					(workspaces.get_children ().nth_data (0).width + 10));
			}
		}
		
		const string CURRENT_WORKSPACE_STYLE = """
		* {
			border-style: solid;
			border-width: 1px 1px 1px 1px;
			-unico-inner-stroke-width: 1px 0 1px 0;
			border-radius: 5px;
			
			background-image: -gtk-gradient (linear,
							left top,
							left bottom,
							from (shade (@selected_bg_color, 1.4)),
							to (shade (@selected_bg_color, 0.98)));
			
			-unico-border-gradient: -gtk-gradient (linear,
							left top, left bottom,
							from (shade (@selected_bg_color, 1.05)),
							to (shade (@selected_bg_color, 0.88)));
			
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
			
			height = 200;
			opacity = 0;
			scale_gravity = Clutter.Gravity.SOUTH_EAST;
			reactive = true;
			
			workspaces = new Clutter.Actor ();
			var box_layout = new Clutter.BoxLayout ();
			box_layout.spacing = 12;
			workspaces.set_layout_manager (box_layout);
			
			bg = new Clutter.CairoTexture (500, (uint)height);
			bg.auto_resize = true;
			bg.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.WIDTH, 0));
			bg.add_constraint (new Clutter.BindConstraint (this, Clutter.BindCoordinate.HEIGHT, 0));
			bg.draw.connect (draw_background);
			
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
			
			tile.x = 5;
			tile.y = 5;
			tile.reactive = true;
			tile.button_release_event.connect (() => {
				var windows = new GLib.List<Window> ();
				plugin.screen.get_active_workspace ().list_windows ().foreach ( (w) => {
					if (w.window_type != Meta.WindowType.NORMAL || w.minimized)
						return;
					
					windows.append (w);
				});
				
				//make sure active window is biggest
				var active_idx = windows.index (plugin.screen.get_display ().get_focus_window ());
				if (active_idx != -1 && active_idx != 0) {
					windows.delete_link (windows.nth (active_idx));
					windows.prepend (plugin.screen.get_display ().get_focus_window ());
				}
				
				unowned Rectangle area;

				plugin.screen.get_monitor_geometry (plugin.screen.get_primary_monitor (), out area);
				
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
			unowned Rectangle area;

			plugin.screen.get_monitor_geometry (plugin.screen.get_primary_monitor (), out area);
			width = area.width;
			height = area.height;			

			workspace_thumb = new Clutter.CairoTexture (120, 120);
			workspace_thumb.height = 120;
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
			current_workspace.height = workspace_thumb.height + 10;
			current_workspace.width  = workspace_thumb.width  + 10;
			current_workspace.auto_resize = true;
			current_workspace.draw.connect (draw_current_workspace);
			
			var path = File.new_for_uri (new GLib.Settings ("org.gnome.desktop.background").get_string ("picture-uri")).get_path ();
			try {
				background_pix = new Gdk.Pixbuf.from_file (path).scale_simple 
				((int)workspace_thumb.width, (int)workspace_thumb.height, Gdk.InterpType.HYPER);
			} catch (Error e) { warning (e.message); }
			add_child (workspace_thumb);
			add_child (bg);
			add_child (tile);
			add_child (current_workspace);
			add_child (workspaces);
			
			workspace_thumb.visible = false; //will only be used for cloning
		}
		
		bool draw_current_workspace (Cairo.Context cr)
		{
			current_workspace_style.get_style_context ().render_activity (cr, 0.5, 0.5, 
				current_workspace.width-1, current_workspace.height-1);
			return false;
		}
		
		bool draw_workspace_thumb (Cairo.Context cr)
		{
			Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, 0.5, 0.5, 
				workspace_thumb.width-1, workspace_thumb.height-1, 5);
			Gdk.cairo_set_source_pixbuf (cr, background_pix, 0.5, 0.5);
			cr.fill_preserve ();
			
			cr.set_line_width (1);
			cr.set_source_rgba (0, 0, 0, 0.6);
			cr.stroke_preserve ();
			
			var grad = new Cairo.Pattern.linear (0, 0, 30, workspace_thumb.height-50);
			grad.add_color_stop_rgba (0.99, 1, 1, 1, 0.2);
			grad.add_color_stop_rgba (1, 1, 1, 1, 0);
			
			cr.set_source (grad);
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
			
			var grad = new Cairo.Pattern.linear (0, 0, 0, 20);
			grad.add_color_stop_rgba (0, 0, 0, 0, 0.4);
			grad.add_color_stop_rgba (1, 0, 0, 0, 0);
			
			cr.rectangle (0, 1, width, 20);
			cr.set_source (grad);
			cr.fill ();
			
			return false;
		}
		
		public override bool key_press_event (Clutter.KeyEvent event)
		{
			switch (event.keyval) {
				case Clutter.Key.Left:
					workspace = plugin.move_workspaces (true);
					return false;
				case Clutter.Key.Right:
					workspace = plugin.move_workspaces (false);
					return false;
				default:
					break;
			}
			
			return true;
		}
		
		public override bool key_release_event (Clutter.KeyEvent event)
		{
			if (event.keyval == Clutter.Key.Alt_L) {
				this.hide ();
				
				return true;
			}
			
			return false;
		}
		
		//FIXME move all this positioning stuff to a separate function which is only called by screen size changes
		public new void show ()
		{
			if (visible)
				return;
			
			plugin.set_input_area (Gala.InputArea.FULLSCREEN);
			plugin.begin_modal ();
			
			animating = true;
			
			int width, height;
			unowned Rectangle area;

			plugin.screen.get_monitor_geometry (plugin.screen.get_primary_monitor (), out area);
			width = area.width;
			height = area.height;
			
			tile.x = width  - 80;
			tile.y = 120;
			
			y = height;
			this.width = width;
			
			/*get the workspaces together*/
			workspaces.remove_all_children ();
			
			for (var i=0;i<plugin.get_screen ().n_workspaces;i++) {
				var space = plugin.get_screen ().get_workspace_by_index (i);
				
				var group = new Clutter.Actor ();
				var icons = new Clutter.Actor ();
				icons.set_layout_manager (new Clutter.BoxLayout ());				
				var backg = new Clutter.Clone (workspace_thumb);
				
				space.list_windows ().foreach ((w) => {
					if (w.window_type != Meta.WindowType.NORMAL)
						return;
					var pix = plugin.get_icon_for_window (w, 32);
					var icon = new GtkClutter.Texture ();
					try {
						icon.set_from_pixbuf (pix);
					} catch (Error e) { warning (e.message); }
					
					icon.reactive = true;
					icon.button_release_event.connect ( () => {
						space.activate_with_focus (w,plugin.screen.get_display ().get_current_time ());
						hide ();
						return false;
					});
					
					icons.add_child (icon);
				});
				
				group.add_child (icons);
				group.add_child (backg);
				
				icons.y = backg.height + 12;
				icons.x = group.width / 2 - icons.width / 2;
				(icons.layout_manager as Clutter.BoxLayout).spacing = 6;
				
				group.height = 160;
				
				group.reactive = true;
				group.button_release_event.connect (() => {
					space.activate (plugin.screen.get_display ().get_current_time ());
					current_workspace.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 300,
						x : workspaces.x - 5 + 
						plugin.screen.get_active_workspace ().index () *
						(workspaces.get_children ().nth_data (0).width + 10));
					hide ();
					return true;
				});
				
				workspaces.add_child (group);
			}
			workspaces.x = this.width / 2 - workspaces.width / 2;
			workspaces.y = 25;
			
			current_workspace.x = workspaces.x - 5 + 
				plugin.screen.get_active_workspace ().index () *
				(workspaces.get_children ().nth_data (0).width + 10);
			current_workspace.y = workspaces.y - 5;
			
			visible = true;
			grab_key_focus ();
			Timeout.add (50, () => animating = false ); //catch hot corner hiding problem
			animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, y : height-this.height, opacity : 255)
				.completed.connect (() => {
			});
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
			this.show ();
			
			bool left = (binding.get_name () == "switch-to-workspace-left");
			workspace = plugin.move_workspaces (left);
			
		}
	}
}
