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

		public void flash_area (int x, int y, int width, int height) throws DBusError, IOError
		{
			debug ("Flashing area");

			double[] keyframes = { 0.3f, 0.8f };
			GLib.Value[] values = { 180U, 0U };

			var transition = new Clutter.KeyframeTransition ("opacity");
			transition.duration = 200;
			transition.remove_on_complete = true;
			transition.progress_mode = Clutter.AnimationMode.LINEAR;
			transition.set_key_frames (keyframes);
			transition.set_values (values);
			transition.set_to_value (0.0f);

			var flash_actor = new Clutter.Actor ();
			flash_actor.set_size (width, height);
			flash_actor.set_position (x, y);
			flash_actor.set_background_color (Clutter.Color.get_static (Clutter.StaticColor.WHITE));
			flash_actor.set_opacity (0);
			flash_actor.transitions_completed.connect ((actor) => {
				wm.top_window_group.remove_child (actor);
				actor.destroy ();
			});

			wm.top_window_group.add_child (flash_actor);
			flash_actor.add_transition ("flash", transition);
		}

		public async void screenshot (bool include_cursor, bool flash, string filename, out bool success, out string filename_used) throws DBusError, IOError
		{
			debug ("Taking screenshot");

			int width, height;
			wm.get_screen ().get_size (out width, out height);

			var image = take_screenshot (0, 0, width, height, include_cursor);

			if (flash) {
				flash_area (0, 0, width, height);
			}

			success = yield save_image (image, filename, out filename_used);
		}

		public async void screenshot_area (int x, int y, int width, int height, bool flash, string filename, out bool success, out string filename_used) throws DBusError, IOError
		{
			debug ("Taking area screenshot");

			yield wait_stage_repaint ();

			var image = take_screenshot (x, y, width, height, false);

			if (flash) {
				flash_area (x, y, width, height);
			}

			success = yield save_image (image, filename, out filename_used);
			if (!success)
				throw new DBusError.FAILED ("Failed to save image");
		}

		public async void screenshot_window (bool include_frame, bool include_cursor, bool flash, string filename, out bool success, out string filename_used) throws DBusError, IOError
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
			if (include_cursor) {
				image = composite_stage_cursor (image, { rect.x, rect.y, rect.width, rect.height });
			}

			if (flash) {
				flash_area (rect.x, rect.y, rect.width, rect.height);
			}

			success = yield save_image (image, filename, out filename_used);
		}

		public async void select_area (out int x, out int y, out int width, out int height) throws DBusError, IOError
		{
			var selection_area = new SelectionArea (wm);
			selection_area.closed.connect (() => Idle.add (select_area.callback));
			wm.ui_group.add (selection_area);
			selection_area.start_selection ();

			yield;
			selection_area.destroy ();

			if (selection_area.cancelled) {
				throw new GLib.IOError.CANCELLED ("Operation was cancelled");
			}

			yield wait_stage_repaint ();
			selection_area.get_selection_rectangle (out x, out y, out width, out height);
		}

		static string find_target_path ()
		{
			// Try to create dedicated "Screenshots" subfolder in PICTURES xdg-dir
			unowned string? base_path = Environment.get_user_special_dir (UserDirectory.PICTURES);
			if (base_path != null && FileUtils.test (base_path, FileTest.EXISTS)) {
				var path = Path.build_path (Path.DIR_SEPARATOR_S, base_path, _("Screenshots"));
				if (FileUtils.test (path, FileTest.EXISTS)) {
					return path;
				} else if (DirUtils.create (path, 0755) == 0) {
					return path;
				} else {
					return base_path;
				}
			}

			return Environment.get_home_dir ();
		}

		static async bool save_image (Cairo.ImageSurface image, string filename, out string used_filename)
		{
			if (!Path.is_absolute (filename)) {
				var path = find_target_path ();
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
				var file = File.new_for_path (used_filename);
				var stream = yield file.create_readwrite_async (FileCreateFlags.NONE);
				yield screenshot.save_to_stream_async (stream.output_stream, "png");
				return true;
			} catch (GLib.Error e) {
				return false;
			}
		}

		Cairo.ImageSurface take_screenshot (int x, int y, int width, int height, bool include_cursor)
		{
			Cairo.ImageSurface image;
#if HAS_MUTTER322
			Clutter.Capture[] captures;
			wm.stage.capture (false, {x, y, width, height}, out captures);

			if (captures.length == 0)
				image = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
			else if (captures.length == 1)
				image = captures[0].image;
			else
				image = composite_capture_images (captures, x, y, width, height);
#else
			unowned Clutter.Backend backend = Clutter.get_default_backend ();
			unowned Cogl.Context context = Clutter.backend_get_cogl_context (backend);

			image = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
			var bitmap = Cogl.bitmap_new_for_data (context, width, height, Cogl.PixelFormat.BGRA_8888_PRE, image.get_stride (), image.get_data ());
			Cogl.framebuffer_read_pixels_into_bitmap (Cogl.get_draw_framebuffer (), x, y, Cogl.ReadPixelsFlags.BUFFER, bitmap);
#endif

			if (include_cursor) {
				image = composite_stage_cursor (image, { x, y, width, height});
			}

			image.mark_dirty ();
			return image;
		}

#if HAS_MUTTER322
		Cairo.ImageSurface composite_capture_images (Clutter.Capture[] captures, int x, int y, int width, int height)
		{
			var image = new Cairo.ImageSurface (captures[0].image.get_format (), width, height);
			var cr = new Cairo.Context (image);

			foreach (unowned Clutter.Capture capture in captures) {
				// Ignore capture regions with scale other than 1 for now; mutter can't
				// produce them yet, so there is no way to test them.
				double capture_scale = 1.0;
				capture.image.get_device_scale (out capture_scale, null);
				if (capture_scale != 1.0)
					continue;

				cr.save ();
				cr.translate (capture.rect.x - x, capture.rect.y - y);
				cr.set_source_surface (capture.image, 0, 0);
				cr.restore ();
			}

			return image;
		}
#endif

		Cairo.ImageSurface composite_stage_cursor (Cairo.ImageSurface image, Cairo.RectangleInt image_rect)
		{
			unowned Meta.CursorTracker cursor_tracker = Meta.CursorTracker.get_for_screen (wm.get_screen ());

			int x, y;
			cursor_tracker.get_pointer (out x, out y, null);

			var region = new Cairo.Region.rectangle (image_rect);
			if (!region.contains_point (x, y)) {
				return image;
			}

			unowned Cogl.Texture texture = cursor_tracker.get_sprite ();
			if (texture == null) {
				return image;
			}

			int width = (int)texture.get_width ();
			int height = (int)texture.get_height ();

			uint8[] data = new uint8[width * height * 4];
			CoglFixes.texture_get_data (texture, Cogl.PixelFormat.RGBA_8888, 0, data);

			var cursor_image = new Cairo.ImageSurface.for_data (data, Cairo.Format.ARGB32, width, height, width * 4);
			var target = new Cairo.ImageSurface (Cairo.Format.ARGB32, image_rect.width, image_rect.height);

			var cr = new Cairo.Context (target);
			cr.set_operator (Cairo.Operator.OVER);
			cr.set_source_surface (image, 0, 0);
			cr.paint ();

			cr.set_operator (Cairo.Operator.OVER);
			cr.set_source_surface (cursor_image, x - image_rect.x, y - image_rect.y);
			cr.paint ();

			return (Cairo.ImageSurface)cr.get_target ();
		}

		async void wait_stage_repaint ()
		{
			ulong signal_id = 0UL;
			signal_id = wm.stage.paint.connect_after (() => {
				wm.stage.disconnect (signal_id);
				Idle.add (wait_stage_repaint.callback);
			});

			wm.stage.queue_redraw ();
			yield;
		}
	}
}
