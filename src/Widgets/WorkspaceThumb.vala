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
		
		GtkClutter.Texture close;
		Clone backg;
		internal CairoTexture indicator;
		Clutter.Actor icons;
		
		bool hovering = false;
		
		static const int indicator_border = 5;
		
		public signal void opened ();//workspace was opened, close view
		public signal void closed ();//workspace has been destroied!
		
		public WorkspaceThumb (Workspace _workspace, Clutter.Texture workspace_thumb)
		{
			workspace = _workspace;
			
			var screen = workspace.get_screen ();
			
			int swidth, sheight;
			screen.get_size (out swidth, out sheight);
			
			height = 160;
			reactive = true;
			
			indicator = new Clutter.CairoTexture (100, 100);
			indicator.draw.connect (draw_indicator);
			indicator.width = workspace_thumb.width + indicator_border*2;
			indicator.height = workspace_thumb.height + indicator_border*2;
			indicator.auto_resize = true;
			indicator.opacity = 0;
			
			backg = new Clone (workspace_thumb);
			backg.x = indicator_border;
			backg.y = indicator_border;
			
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
			
			list_windows ();
			
			add_child (indicator);
			add_child (backg);
			add_child (icons);
			
			icons.y = Math.floorf (backg.height + indicator_border) - 5;
			icons.x = Math.floorf (width / 2 - icons.width / 2);
			(icons.layout_manager as Clutter.BoxLayout).spacing = 6;
			
			//get window thumbs
			var aspect = backg.width/swidth;
			Compositor.get_window_actors (screen).foreach ((w) => {
				var meta_window = w.get_meta_window ();
				var type = meta_window.window_type;
				
				if ((!(w.get_workspace () == workspace.index ()) && 
					!meta_window.is_on_all_workspaces ()) ||
					meta_window.minimized ||
					!meta_window.is_on_primary_monitor () ||
					(type != WindowType.NORMAL && 
					type != WindowType.DIALOG &&
					type != WindowType.MODAL_DIALOG))
					return;
				
				var clone = new Clone (w.get_texture ());
				clone.width = aspect * clone.width;
				clone.height = aspect * clone.height;
				clone.x = aspect * w.x + indicator_border;
				clone.y = aspect * w.y + indicator_border;
				
				add_child (clone);
			});
			
			if (workspace.index () != screen.n_workspaces - 1) //dont allow closing the last one
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
				
				closed ();
				
				return true;
			});
			
			//last workspace, show plus button and so on
			if (workspace.index () == workspace.get_screen ().n_workspaces - 1) { //give the last one a different style
				backg.opacity = 127;
				
				var css = new Gtk.CssProvider ();
				var img = new Gtk.Image ();
				try {
					css.load_from_data ("*{text-shadow:0 1 #f00;color:alpha(#fff, 0.8);}", -1);
				} catch (Error e) { warning(e.message); }
				img.get_style_context ().add_provider (css, 20000);
				
				var plus = new GtkClutter.Texture ();
				try {
					var pix = Gtk.IconTheme.get_default ().choose_icon ({"list-add-symbolic", "list-add"}, 32, 0).
						load_symbolic_for_context (img.get_style_context ());
					plus.set_from_pixbuf (pix);
				} catch (Error e) { warning (e.message); }
				
				plus.x = width / 2 - plus.width / 2;
				plus.y = (backg.x + backg.height) / 2 - plus.height / 2;
				
				add_child (plus);
			}
		}
		
		/*get a list of all running applications and put them as icons below the workspace thumb*/
		void list_windows ()
		{
			var shown_applications = new List<Bamf.Application> (); //show each icon only once, so log the ones added
			
			icons = new Actor ();
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
					workspace.activate_with_focus (w, workspace.get_screen ().get_display ().get_current_time ());
					hide ();
					return false;
				});
				
				icons.add_child (icon);
			});
		}
		
		public override bool button_release_event (ButtonEvent event)
		{
			var screen = workspace.get_screen ();
			
			workspace.activate (screen.get_display ().get_current_time ());
			
			opened ();
			
			return true;
		}
		
		public override bool enter_event (CrossingEvent event)
		{
			var screen = workspace.get_screen ();
			
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
			var screen = workspace.get_screen ();
			
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
		
		/*drawing the indicator*/
		static const string CURRENT_WORKSPACE_STYLE = """
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
		static Gtk.Menu current_workspace_style; //dummy item for drawing
		
		bool draw_indicator (Cairo.Context cr)
		{
			if (current_workspace_style == null) {
				current_workspace_style = new Gtk.Menu ();
				var provider = new Gtk.CssProvider ();
				try {
					provider.load_from_data (CURRENT_WORKSPACE_STYLE, -1);
				} catch (Error e) { warning (e.message); }
				current_workspace_style.get_style_context ().add_provider (provider, 20000);
			}
			
			current_workspace_style.get_style_context ().render_activity (cr, 0, 0, 
				indicator.width, indicator.height);
			
			return false;
		}
		
	}
	
}
