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
using Clutter;

namespace Gala
{
	public class WorkspaceThumb : Clutter.Actor
	{
		// indicator style
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

		//dummy item for indicator drawing
		static Gtk.Image current_workspace_style;
		
		static const int INDICATOR_BORDER = 5;
		static const int APP_ICON_SIZE = 32;
		static const float THUMBNAIL_HEIGHT = 80.0f;
		static const uint CLOSE_BUTTON_DELAY = 500;
		
		public signal void clicked ();
		public signal void closed ();
		public signal void window_on_last ();
		
		public unowned Workspace? workspace { get; set; }
		
		unowned Screen screen;
		
		static GtkClutter.Texture? plus = null;
		
		Clone wallpaper;
		Clutter.Actor windows;
		Clutter.Actor icons;
		CairoTexture indicator;
		GtkClutter.Texture close_button;
		
		uint hover_timer = 0;
		
		public WorkspaceThumb (Workspace _workspace)
		{
			workspace = _workspace;
			screen = workspace.get_screen ();
			
			screen.workspace_switched.connect (handle_workspace_switched);
			screen.workspace_added.connect (workspace_added);

			workspace.window_added.connect (handle_window_added);
			workspace.window_removed.connect (handle_window_removed);
			
			int swidth, sheight;
			screen.get_size (out swidth, out sheight);
			
			var width = Math.floorf ((THUMBNAIL_HEIGHT / sheight) * swidth);
			
			reactive = true;
						
			indicator = new Clutter.CairoTexture ((uint)width + 2 * INDICATOR_BORDER, (uint)THUMBNAIL_HEIGHT + 2 * INDICATOR_BORDER);
			indicator.draw.connect (draw_indicator);
			indicator.auto_resize = true;
			indicator.opacity = 0;
			handle_workspace_switched (-1, screen.get_active_workspace_index (), MotionDirection.LEFT);
			
			// FIXME find a nice way to draw a border around it, maybe combinable with the indicator using a ShaderEffect
			wallpaper = new Clone (Compositor.get_background_actor_for_screen (screen));
			wallpaper.x = INDICATOR_BORDER;
			wallpaper.y = INDICATOR_BORDER;
			wallpaper.height = THUMBNAIL_HEIGHT;
			wallpaper.width = width;
			
			close_button = new GtkClutter.Texture ();
			try {
				close_button.set_from_pixbuf (Granite.Widgets.get_close_pixbuf ());
			} catch (Error e) { warning (e.message); }
			close_button.x = -12.0f;
			close_button.y = -10.0f;
			close_button.reactive = true;
			close_button.scale_gravity = Clutter.Gravity.CENTER;
			close_button.scale_x = 0;
			close_button.scale_y = 0;
			
			icons = new Actor ();
			icons.layout_manager = new BoxLayout ();
			(icons.layout_manager as Clutter.BoxLayout).spacing = 6;
			icons.height = APP_ICON_SIZE;
			
			windows = new Actor ();
			windows.x = INDICATOR_BORDER;
			windows.y = INDICATOR_BORDER;
			windows.height = THUMBNAIL_HEIGHT;
			windows.width = width;
			windows.clip_to_allocation = true;
			
			add_child (indicator);
			add_child (wallpaper);
			add_child (windows);
			add_child (icons);
			add_child (close_button);
			
			//kill the workspace
			close_button.button_release_event.connect (() => {
				animate (Clutter.AnimationMode.LINEAR, 250, width : 0.0f, opacity : 0);
				
				workspace.list_windows ().foreach ((w) => {
					if (w.window_type != WindowType.DOCK) {
						var gw = Gdk.X11Window.foreign_new_for_display (Gdk.Display.get_default (), 
							w.get_xwindow ());
						if (gw != null)
							gw.destroy ();
					}
				});
				
				GLib.Timeout.add (250, () => {
					workspace.window_added.disconnect (handle_window_added);
					workspace.window_removed.disconnect (handle_window_removed);
					
					closed ();
					return false;
				});
				
				return true;
			});
			
			if (plus == null) {
				var css = new Gtk.CssProvider ();
				var img = new Gtk.Image ();
				try {
					css.load_from_data ("*{text-shadow:0 1 #f00;color:alpha(#fff, 0.8);}", -1);
				} catch (Error e) { warning(e.message); }
				img.get_style_context ().add_provider (css, 20000);
				
				plus = new GtkClutter.Texture ();
				try {
					var pix = Gtk.IconTheme.get_default ().choose_icon ({"list-add-symbolic", "list-add"}, (int)THUMBNAIL_HEIGHT / 2, 0).
						load_symbolic_for_context (img.get_style_context ());
					plus.set_from_pixbuf (pix);
				} catch (Error e) { warning (e.message); }
				
				plus.x = wallpaper.x + wallpaper.width / 2 - plus.width / 2;
				plus.y = wallpaper.y + wallpaper.height / 2 - plus.height / 2;
			}
			
			check_last_workspace ();
			
			visible = false;			
		}
		
		~WorkspaceThumb ()
		{
			screen.workspace_switched.disconnect (handle_workspace_switched);
			screen.workspace_added.disconnect (workspace_added);
		}
		
		bool draw_indicator (Cairo.Context cr)
		{
			if (current_workspace_style == null) {
				current_workspace_style = new Gtk.Image ();
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
		
		void workspace_added (int index)
		{
			check_last_workspace ();
		}

		void update_windows ()
		{
			windows.remove_all_children ();
			
			if (workspace == null)
				return;
			
			int swidth, sheight;
			screen.get_size (out swidth, out sheight);
			
			// add window thumbnails
			var aspect = windows.width / swidth;
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
				clone.x = aspect * w.x;
				clone.y = aspect * w.y;
				
				windows.add_child (clone);
			});
		}

		void update_icons ()
		{
			icons.remove_all_children ();
			
			if (workspace == null)
				return;
			
			//show each icon only once, so log the ones added
			var shown_applications = new List<Bamf.Application> ();
			
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
					icon.set_from_pixbuf (Gala.Plugin.get_icon_for_window (w, APP_ICON_SIZE));
				} catch (Error e) { warning (e.message); }
				
				icon.reactive = true;
				icon.button_release_event.connect ( () => {
					workspace.activate_with_focus (w, workspace.get_screen ().get_display ().get_current_time ());
					return false;
				});
				
				icons.add_child (icon);
			});
			
			icons.x = Math.floorf (wallpaper.x + wallpaper.width / 2 - icons.width / 2);
			icons.y = Math.floorf (wallpaper.y + wallpaper.height - 5);
		}

		void check_last_workspace ()
		{
			//last workspace, show plus button and so on
			//give the last one a different style
			
			if (workspace == null)
				return;
			
			if (workspace.index () == screen.n_workspaces - 1) {
				wallpaper.opacity = 127;
				if (!contains (plus))
					add_child (plus);
			} else {
				wallpaper.opacity = 255;
				if (contains (plus))
					remove_child (plus);
			}
		}
		
		void handle_workspace_switched (int index_old, int index_new, Meta.MotionDirection direction)
		{
			if (index_old == index_new)
				return;
			
			if (workspace == null)
				return;
			
			if (workspace.index () == index_old)
				indicator.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity : 0);
			else if (workspace.index () == index_new)
				indicator.animate (Clutter.AnimationMode.EASE_OUT_QUAD, 200, opacity : 255);
		}
		
		void handle_window_added (Meta.Window window)
		{
			if (workspace != null && workspace.index () == screen.n_workspaces - 1 && workspace.n_windows > 0)
				window_on_last ();
		}
		
		void handle_window_removed (Meta.Window window)
		{
			if (workspace != null && workspace.n_windows == 0) {
				workspace.window_added.disconnect (handle_window_added);
				workspace.window_removed.disconnect (handle_window_removed);
				
				closed ();
			}
		}
		
		public override void hide ()
		{
			base.hide ();
			
			icons.remove_all_children ();
			windows.remove_all_children ();
		}
		
		public override void show ()
		{
			check_last_workspace ();
			
			update_icons ();
			update_windows ();
			
			base.show ();
		}
		
		public override bool button_release_event (ButtonEvent event)
		{
			if (workspace == null)
				return true;
			
			workspace.activate (screen.get_display ().get_current_time ());
			
			clicked ();
			
			return true;
		}
		
		public override bool enter_event (CrossingEvent event)
		{
			if (workspace == null)
				return true;
			
			if (workspace.index () == screen.n_workspaces - 1) {
				wallpaper.animate (AnimationMode.EASE_OUT_QUAD, 300, opacity : 210);
				return true;
			}
			
			if (hover_timer > 0)
				GLib.Source.remove (hover_timer);
			
			hover_timer = Timeout.add (CLOSE_BUTTON_DELAY, () => {
				close_button.visible = true;
				close_button.animate (AnimationMode.EASE_OUT_ELASTIC, 400, scale_x : 1.0f, scale_y : 1.0f);
				return false;
			});
			
			return true;
		}
		
		public override bool leave_event (CrossingEvent event)
		{
			if (contains (event.related))
				return false;
			
			if (hover_timer > 0) {
				GLib.Source.remove (hover_timer);
				hover_timer = 0;
			}
			
			if (workspace == null)
				return false;
			
			if (workspace.index () == screen.n_workspaces - 1)
				wallpaper.animate (AnimationMode.EASE_OUT_QUAD, 400, opacity : 127);
			else
				close_button.animate (AnimationMode.EASE_IN_QUAD, 400, scale_x : 0.0f, scale_y : 0.0f)
					.completed.connect (() => close_button.visible = false );
			
			return false;
		}
	}
}
