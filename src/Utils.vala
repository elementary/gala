using Meta;

namespace Gala.Utils
{
	
	public enum InputArea {
		NONE,
		FULLSCREEN,
		HOT_CORNER
	}
	
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
	
	/**
	 * returns a pixbuf for the application of this window or a default icon
	 **/
	public static Gdk.Pixbuf get_icon_for_window (Window window, int size)
	{
		unowned Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default ();
		Gdk.Pixbuf? image = null;
		
		var app = Bamf.Matcher.get_default ().get_application_for_xid ((uint32)window.get_xwindow ());
		if (app != null && app.get_desktop_file () != null) {
			try {
				var appinfo = new DesktopAppInfo.from_filename (app.get_desktop_file ());
				if (appinfo != null) {
					var iconinfo = icon_theme.lookup_by_gicon (appinfo.get_icon (), size, 0);
					if (iconinfo != null)
						image = iconinfo.load_icon ();
				}
			} catch (Error e) {
				warning (e.message);
			}
		}
		
		if (image == null) {
			try {
				image = icon_theme.load_icon ("application-default-icon", size, 0);
			} catch (Error e) {
				warning (e.message);
			}
		}
		
		if (image == null) {
			image = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, 1, 1);
			image.fill (0x00000000);
		}
		
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
	public void set_input_area (Screen screen, InputArea area)
	{
		var display = screen.get_display ();
		
		X.Xrectangle rect;
		int width, height;
		screen.get_size (out width, out height);
		
		switch (area) {
			case InputArea.FULLSCREEN:
				rect = {0, 0, (ushort)width, (ushort)height};
				break;
			case InputArea.HOT_CORNER: //leave one pix in the bottom left
				rect = {(short)(width - 1), (short)(height - 1), 1, 1};
				break;
			default:
				Util.empty_stage_input_region (screen);
				return;
		}
		
		var xregion = X.Fixes.create_region (display.get_xdisplay (), {rect});
		Util.set_stage_input_region (screen, xregion);
	}
	
	/**
	 * get the number of toplevel windows on a workspace
	 **/
	public uint get_n_windows (Workspace workspace)
	{
		var n = 0;
		foreach (var window in workspace.list_windows ()) {
			if (window.window_type == WindowType.NORMAL ||
				window.window_type == WindowType.DIALOG ||
				window.window_type == WindowType.MODAL_DIALOG)
				n ++;
		}
		
		return n;
	}
	
	
	static Gtk.CssProvider fallback_style = null;
	
	public Gtk.CssProvider get_default_style ()
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
