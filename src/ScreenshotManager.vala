//
//  Copyright (C) 2016 Rico Tzschichholz, Santiago León O.
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

namespace Gala
{
	[DBus (name="org.gnome.Shell.Screenshot")]
	public class ScreenshotManager : Object
	{
		static ScreenshotManager? instance;

		[DBus (visible = false)]
		public static unowned ScreenshotManager init (WindowManager wm)
		{
			if (instance == null)
				instance = new ScreenshotManager (wm);

			return instance;
		}

		WindowManager wm;

		ScreenshotManager (WindowManager _wm)
		{
			wm = _wm;
		}

		public void flash_area (int x, int y, int width, int height)
		{
			warning ("FlashArea not implemented");
		}

		public void screenshot (bool include_cursor, bool flash, string filename, out bool success, out string filename_used)
		{
			debug ("Taking screenshot");

			int width, height;
			wm.get_screen ().get_size (out width, out height);

			var image = take_screenshot (0, 0, width, height);
			success = save_image (image, filename, out filename_used);
		}

		public void screenshot_area (int x, int y, int width, int height, bool flash, string filename, out bool success, out string filename_used)
		{
			warning ("ScreenShotArea not implemented");
			filename_used = "";
			success = false;
		}

		public void screenshot_window (bool include_frame, bool include_cursor, bool flash, string filename, out bool success, out string filename_used)
		{
			debug ("Taking window screenshot");

			var window = wm.get_screen ().get_display ().get_focus_window ();
			var window_actor = (Meta.WindowActor) window.get_compositor_private ();
			unowned Meta.ShapedTexture window_texture = (Meta.ShapedTexture) window_actor.get_texture ();

			float actor_x, actor_y;
			window_actor.get_position (out actor_x, out actor_y);

			var rect = window.get_frame_rect ();
			if (include_frame) {
				rect = window.frame_rect_to_client_rect (rect);
			}

			Cairo.RectangleInt clip = { rect.x - (int) actor_x, rect.y - (int) actor_y, rect.width, rect.height };
			var image = (Cairo.ImageSurface) window_texture.get_image (clip);
			success = save_image (image, filename, out filename_used);
		}

		public void select_area (out int x, out int y, out int width, out int height)
		{
			warning ("SelectArea not implemented");
			x = y = width = height = 0;
		}

		static bool save_image (Cairo.ImageSurface image, string filename, out string used_filename)
		{
			if (!Path.is_absolute (filename)) {
				string path = Environment.get_user_special_dir (UserDirectory.PICTURES);
				if (!FileUtils.test (path, FileTest.EXISTS)) {
					path = Environment.get_home_dir ();
				}

				if (!filename.has_suffix (".png")) {
					used_filename = Path.build_filename (path, filename.concat (".png"), null);
				} else {
					used_filename = Path.build_filename (path, filename, null);
				}
			} else {
				used_filename = filename;
			}

			try {
				var screenshot = Gdk.pixbuf_get_from_surface (image, 0, 0, image.get_width (), image.get_height ());
				screenshot.save (used_filename, "png");
				return true;
			} catch (GLib.Error e) {
				return false;
			}
		}

		static Cairo.ImageSurface take_screenshot (int x, int y, int width, int height)
		{
			unowned Clutter.Backend backend = Clutter.get_default_backend ();
			unowned Cogl.Context context = Clutter.backend_get_cogl_context (backend);

			var image = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
			var bitmap = Cogl.bitmap_new_for_data (context, width, height, Cogl.PixelFormat.BGRA_8888_PRE, image.get_stride (), image.get_data ());
			Cogl.framebuffer_read_pixels_into_bitmap (Cogl.get_draw_framebuffer (), x, y, Cogl.ReadPixelsFlags.BUFFER, bitmap);
			image.mark_dirty ();

			return image;
		}

	}
}
