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

using Meta;
using Clutter;

namespace Gala
{
	
	public class WorkspaceThumb : Clutter.Actor
	{
		
		Workspace workspace;
		Plugin plugin;
		
		GtkClutter.Texture close;
		Clone backg;
		
		bool hovering = false;
		
		public signal void opened ();//workspace was opened, close view
		
		public WorkspaceThumb (Workspace _workspace, Plugin _plugin, Clutter.Texture workspace_thumb)
		{
			workspace = _workspace;
			plugin = _plugin;
			
			var screen = plugin.get_screen ();
			int swidth, sheight;
			screen.get_size (out swidth, out sheight);
			
			height = 160;
			reactive = true;
			
			var backg = new Clone (workspace_thumb);
			
			//close button
			close = new GtkClutter.Texture ();
			try {
				close.set_from_pixbuf (Granite.Widgets.get_close_pixbuf ());
			} catch (Error e) { warning (e.message); }
			close.x = -12.0f;
			close.y = -10.0f;
			close.reactive = true;
			close.scale_gravity = Clutter.Gravity.CENTER;
			close.scale_x = 0;
			close.scale_y = 0;
			
			//list applications
			var shown_applications = new List<Bamf.Application> (); //show each icon only once, so log the ones added
			
			var icons = new Actor ();
			icons.layout_manager = new BoxLayout ();
			
			workspace.list_windows ().foreach ((w) => {
				if (w.window_type != Meta.WindowType.NORMAL || w.minimized)
					return;
				
				var app = Bamf.Matcher.get_default ().get_application_for_xid ((uint32)w.get_xwindow ());
				if (shown_applications.index (app) != -1)
					return;
				
				if (app != null)
					shown_applications.append (app);
				
				var icon = new GtkClutter.Texture ();
				try {
					icon.set_from_pixbuf (Gala.Plugin.get_icon_for_window (w, 32));
				} catch (Error e) { warning (e.message); }
				
				icon.reactive = true;
				icon.button_release_event.connect ( () => {
					workspace.activate_with_focus (w, screen.get_display ().get_current_time ());
					hide ();
					return false;
				});
				
				icons.add_child (icon);
			});
			
			add_child (backg);
			add_child (icons);
			
			icons.y = Math.floorf (backg.height + 7);
			icons.x = Math.floorf (width / 2 - icons.width / 2);
			(icons.layout_manager as Clutter.BoxLayout).spacing = 6;
			
			//get window thumbs
			var aspect = backg.width/swidth;
			Compositor.get_window_actors (screen).foreach ((w) => {
				if (!(w.get_workspace () == workspace.index ()) && 
					!w.get_meta_window ().is_on_all_workspaces ())
					return;
				
				var clone = new Clone (w.get_texture ());
				clone.width = aspect * clone.width;
				clone.height = aspect * clone.height;
				clone.x = aspect * w.x;
				clone.y = aspect * w.y;
				
				add_child (clone);
			});
			
			if (workspace.index () != screen.n_workspaces - 1)//dont allow closing the last one
				add_child (close);
			
			//kill the workspace
			close.button_release_event.connect (() => {
				animate (Clutter.AnimationMode.LINEAR, 150, width:0.0f, opacity:0).completed.connect (() => {
					destroy ();
				});
				
				workspace.list_windows ().foreach ((w) => {
					if (w.window_type != WindowType.DOCK) {
						var gw = Gdk.X11Window.foreign_new_for_display (Gdk.Display.get_default (), 
							w.get_xwindow ());
						if (gw != null)
							gw.destroy ();
					}
				});
				
				//current_workspace.animate (Clutter.AnimationMode.EASE_IN_SINE, 100, opacity:0);
				
				Timeout.add (250, () => { //give the windows time to close
					screen.remove_workspace (workspace, screen.get_display ().get_current_time ());
					
					/*scroll.visible = workspaces.width > width;
					if (scroll.visible) {
						if (workspaces.x + workspaces.width < width)
							workspaces.x = width - workspaces.width;
						scroll.width = width/workspaces.width*width;
					} else {
						workspaces.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 400, x:width / 2 - workspaces.width / 2).
							completed.connect (() => {
							Timeout.add (250, () => {
								//workspace = screen.get_active_workspace ().index ();
								//current_workspace.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 250, opacity:255);
								return false;
							});
						});
					}*/
					return false;
				});
				
				return true;
			});
			
			//last workspace, show plus button and so on
			if (workspace.index () == plugin.get_screen ().n_workspaces - 1) { //give the last one a different style
				backg.opacity = 127;
				
				var css = new Gtk.CssProvider ();
				var img = new Gtk.Image ();
				try {
					css.load_from_data ("*{text-shadow:0 1 #f00;color:alpha(#fff, 0.8);}", -1);
				} catch (Error e) { warning(e.message); }
				img.get_style_context ().add_provider (css, 20000);
				
				var plus = new GtkClutter.Texture ();
				try {
					var pix = Gtk.IconTheme.get_default ().choose_icon ({"list-add-symbolic", "list-add"}, 48, 0).
						load_symbolic_for_context (img.get_style_context ());
					plus.set_from_pixbuf (pix);
				} catch (Error e) { warning (e.message); }
				
				plus.x = width / 2 - plus.width / 2;
				plus.y = (backg.x + backg.height) / 2 - plus.height / 2;
				
				add_child (plus);
			}
		}
		
		public override bool button_release_event (ButtonEvent event)
		{
			var screen = plugin.get_screen ();
			
			workspace.activate (screen.get_display ().get_current_time ());
			
			opened ();
			//workspace = screen.get_active_workspace ().index ();
			return true;
		}
		
		public override bool enter_event (CrossingEvent event)
		{
			var screen = plugin.get_screen ();
			
			if (workspace.index () == screen.n_workspaces - 1)
				backg.animate (AnimationMode.EASE_OUT_QUAD, 300, opacity:210);
			else {
				Timeout.add (500, () => {
					close.visible = true;
					if (hovering)
						close.animate (AnimationMode.EASE_OUT_ELASTIC, 400, scale_x:1.0f, scale_y:1.0f);
					return false;
				});
			}
			
			hovering = true;
			
			return true;
		}
		
		public override bool leave_event (CrossingEvent event)
		{
			var screen = plugin.get_screen ();
			
			if (contains (event.related) || screen.get_workspaces ().index (workspace) < 0)
				return false;
			
			if (workspace.index () == screen.n_workspaces - 1)
				backg.animate (AnimationMode.EASE_OUT_QUAD, 400, opacity:127);
			else
				close.animate (AnimationMode.EASE_IN_QUAD, 400, scale_x:0.0f, scale_y:0.0f)
					.completed.connect (() => close.visible = false );
			
			hovering = false;
			
			return false;
		}
	}
	
}
