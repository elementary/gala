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

using Gala;

namespace Gala
{
	public class Utils
	{
		/*
		 * Reload shadow settings
		 */
		public static void reload_shadow ()
		{
			var factory = ShadowFactory.get_default ();
			var settings = ShadowSettings.get_default ();
			Meta.ShadowParams shadow;
			
			//normal focused
			shadow = settings.get_shadowparams ("normal_focused");
			factory.set_params ("normal", true, shadow);
			
			//normal unfocused
			shadow = settings.get_shadowparams ("normal_unfocused");
			factory.set_params ("normal", false, shadow);
			
			//menus
			shadow = settings.get_shadowparams ("menu");
			factory.set_params ("menu", false, shadow);
			factory.set_params ("dropdown-menu", false, shadow);
			factory.set_params ("popup-menu", false, shadow);
			
			//dialog focused
			shadow = settings.get_shadowparams ("dialog_focused");
			factory.set_params ("dialog", true, shadow);
			factory.set_params ("modal_dialog", false, shadow);
			
			//dialog unfocused
			shadow = settings.get_shadowparams ("normal_unfocused");
			factory.set_params ("dialog", false, shadow);
			factory.set_params ("modal_dialog", false, shadow);
		}
		
		// Cache xid:pixbuf and icon:pixbuf pairs to provide a faster way aquiring icons
		static Gee.HashMap<string, Gdk.Pixbuf> xid_pixbuf_cache;
		static Gee.HashMap<string, Gdk.Pixbuf> icon_pixbuf_cache;
		static uint cache_clear_timeout = 0;
		
		static construct
		{
			xid_pixbuf_cache = new Gee.HashMap<string, Gdk.Pixbuf> ();
			icon_pixbuf_cache = new Gee.HashMap<string, Gdk.Pixbuf> ();
		}
		
		/**
		 * Clean icon caches
		 */
		static void clean_icon_cache (uint32[] xids)
		{
			var list = xid_pixbuf_cache.keys.to_array ();
			var pixbuf_list = icon_pixbuf_cache.values.to_array ();
			var icon_list = icon_pixbuf_cache.keys.to_array ();

			foreach (var xid_key in list) {
				var xid = (uint32)uint64.parse (xid_key.split ("::")[0]);
				if (!(xid in xids)) {
					var pixbuf = xid_pixbuf_cache.get (xid_key);
					for (var j = 0; j < pixbuf_list.length; j++) {
						if (pixbuf_list[j] == pixbuf) {
							xid_pixbuf_cache.unset (icon_list[j]);
						}
					}

					xid_pixbuf_cache.unset (xid_key);
				}
			}
		}
		
		public static void request_clean_icon_cache (uint32[] xids)
		{
			if (cache_clear_timeout > 0)
				GLib.Source.remove (cache_clear_timeout);
			
			cache_clear_timeout = Timeout.add_seconds (30, () => {
				cache_clear_timeout = 0;
				Idle.add (() => {
					clean_icon_cache (xids);
					return false;
				});
				return false;
			});
		}
		
		/**
		 * returns a pixbuf for the application of this window or a default icon
		 **/
		public static Gdk.Pixbuf get_icon_for_window (Window window, int size)
		{
			Gdk.Pixbuf? result = null;
			
			var xid = (uint32)window.get_xwindow ();
			var xid_key = "%u::%i".printf (xid, size);
			
			if ((result = xid_pixbuf_cache.get (xid_key)) != null)
				return result;
			
			var app = Bamf.Matcher.get_default ().get_application_for_xid (xid);
			result = get_icon_for_application (app, size);
			
			xid_pixbuf_cache.set (xid_key, result);
			
			return result;
		}
		
		/**
		 * returns a pixbuf for this application or a default icon
		 **/
		public static Gdk.Pixbuf get_icon_for_application (Bamf.Application app, int size)
		{
			Gdk.Pixbuf? image = null;
			bool not_cached = false;
			
			string? icon = null;
			string? icon_key = null;
			
			if (app != null && app.get_desktop_file () != null) {
				try {
					var appinfo = new DesktopAppInfo.from_filename (app.get_desktop_file ());
					if (appinfo != null) {
						icon = Plank.Drawing.DrawingService.get_icon_from_gicon (appinfo.get_icon ());
						icon_key = "%s::%i".printf (icon, size);
						if ((image = icon_pixbuf_cache.get (icon_key)) == null) {
							image = Plank.Drawing.DrawingService.load_icon (icon, size, size);
							not_cached = true;
						}
					}
				} catch (Error e) {
					warning (e.message);
				}
			}
			
			if (image == null) {
				try {
					unowned Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default ();
					icon = "application-default-icon";
					icon_key = "%s::%i".printf (icon, size);
					if ((image = icon_pixbuf_cache.get (icon_key)) == null) {
						image = icon_theme.load_icon (icon, size, 0);
						not_cached = true;
					}
				} catch (Error e) {
					warning (e.message);
				}
			}
			
			if (image == null) {
				icon = "";
				icon_key = "::%i".printf (size);
				if ((image = icon_pixbuf_cache.get (icon_key)) == null) {
					image = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, size, size);
					image.fill (0x00000000);
					not_cached = true;
				}
			}
			
			if (size != image.width || size != image.height)
				image = Plank.Drawing.DrawingService.ar_scale (image, size, size);
			
			if (not_cached)
				icon_pixbuf_cache.set (icon_key, image);
			
			return image;
		}
		
		/**
		 * get the next window that should be active on a workspace right now
		 **/
		public static Window get_next_window (Meta.Workspace workspace, bool backward=false)
		{
			var screen = workspace.get_screen ();
			var display = screen.get_display ();
			
			var window = display.get_tab_next (Meta.TabList.NORMAL, screen, 
				screen.get_active_workspace (), null, backward);
			
			if (window == null)
				window = display.get_tab_current (Meta.TabList.NORMAL, screen, workspace);
			
			return window;
		}
		
		/**
		 * set the area where clutter can receive events
		 **/
		public static void set_input_area (Screen screen, InputArea area)
		{
			var display = screen.get_display ();
			
			X.Xrectangle[] rects = {};
			int width, height;
			screen.get_size (out width, out height);
			var geometry = screen.get_monitor_geometry (screen.get_primary_monitor ());
			
			switch (area) {
				case InputArea.FULLSCREEN:
					X.Xrectangle rect = {0, 0, (ushort)width, (ushort)height};
					rects = {rect};
					break;
				case InputArea.HOT_CORNER:
					var schema = BehaviorSettings.get_default ().schema;
					
					// if ActionType is NONE make it 0 sized
					ushort tl_size = (schema.get_enum ("hotcorner-topleft") != ActionType.NONE ? 1 : 0);
					ushort tr_size = (schema.get_enum ("hotcorner-topright") != ActionType.NONE ? 1 : 0);
					ushort bl_size = (schema.get_enum ("hotcorner-bottomleft") != ActionType.NONE ? 1 : 0);
					ushort br_size = (schema.get_enum ("hotcorner-bottomright") != ActionType.NONE ? 1 : 0);
					
					X.Xrectangle topleft = {(short)geometry.x, (short)geometry.y, tl_size, tl_size};
					X.Xrectangle topright = {(short)(geometry.x + geometry.width - 1), (short)geometry.y, tr_size, tr_size};
					X.Xrectangle bottomleft = {(short)geometry.x, (short)(geometry.y + geometry.height - 1), bl_size, bl_size};
					X.Xrectangle bottomright = {(short)(geometry.x + geometry.width - 1), (short)(geometry.y + geometry.height - 1), br_size, br_size};
					
					rects = {topleft, topright, bottomleft, bottomright};
					break;
				case InputArea.NONE:
				default:
					Util.empty_stage_input_region (screen);
					return;
			}
			
			var xregion = X.Fixes.create_region (display.get_xdisplay (), rects);
			Util.set_stage_input_region (screen, xregion);
		}
		
		/**
		 * get the number of toplevel windows on a workspace
		 **/
		public static uint get_n_windows (Workspace workspace)
		{
			var n = 0;
			foreach (var window in workspace.list_windows ()) {
				if (window.is_on_all_workspaces ())
					continue;
				if (window.window_type == WindowType.NORMAL ||
					window.window_type == WindowType.DIALOG ||
					window.window_type == WindowType.MODAL_DIALOG)
					n ++;
			}
		
			return n;
		}
		
		static Gtk.CssProvider fallback_style = null;
		
		public static Gtk.CssProvider get_default_style ()
		{
			if (fallback_style == null) {
				fallback_style = new Gtk.CssProvider ();
				try {
					fallback_style.load_from_path (Config.PKGDATADIR + "/gala.css");
				} catch (Error e) { warning (e.message); }
			}
			
			return fallback_style;
		}
	}
}
