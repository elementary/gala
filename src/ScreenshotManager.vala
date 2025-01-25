//
//  Copyright (C) 2016 Rico Tzschichholz, Santiago León O.
//                2025 elementary, Inc.
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

namespace Gala {
    private const string EXTENSION = ".png";
    private const int UNCONCEAL_TEXT_TIMEOUT = 2000;

    [DBus (name="org.gnome.Shell.Screenshot")]
    public class ScreenshotManager : Object {
        private WindowManager wm;
        private NotificationsManager notifications_manager;
        private Settings desktop_settings;

        private string prev_font_regular;
        private string prev_font_document;
        private string prev_font_mono;
        private uint conceal_timeout;

        [DBus (visible = false)]
        public ScreenshotManager (WindowManager _wm, NotificationsManager _notifications_manager) {
            wm = _wm;
            notifications_manager = _notifications_manager;
        }

        construct {
            desktop_settings = new Settings ("org.gnome.desktop.interface");
        }

        public void flash_area (int x, int y, int width, int height) throws DBusError, IOError {
            debug ("Flashing area");

            double[] keyframes = { 0.3f, 0.8f };
            GLib.Value[] values = { 180U, 0U };

            var transition = new Clutter.KeyframeTransition ("opacity") {
                duration = 200,
                remove_on_complete = true,
                progress_mode = Clutter.AnimationMode.LINEAR
            };
            transition.set_key_frames (keyframes);
            transition.set_values (values);
            transition.set_to_value (0.0f);

            var flash_actor = new Clutter.Actor ();
            flash_actor.set_size (width, height);
            flash_actor.set_position (x, y);
#if HAS_MUTTER47
            flash_actor.set_background_color (Cogl.Color.from_string ("white"));
#elif HAS_MUTTER46
            flash_actor.set_background_color (Clutter.Color.from_pixel (0xffffffffu));
#else
            flash_actor.set_background_color (Clutter.Color.get_static (Clutter.StaticColor.WHITE));
#endif
            flash_actor.set_opacity (0);
            flash_actor.transitions_completed.connect ((actor) => {
                wm.ui_group.remove_child (actor);
                actor.destroy ();
            });

            wm.ui_group.add_child (flash_actor);
            flash_actor.add_transition ("flash", transition);
        }

        public async void screenshot (bool include_cursor, bool flash, string filename, out bool success, out string filename_used) throws DBusError, IOError {
            debug ("Taking screenshot");

            unowned var display = wm.get_display ();

            int width, height;
            display.get_size (out width, out height);

            var image = take_screenshot (0, 0, width, height, include_cursor);
            unconceal_text ();

            if (flash) {
                flash_area (0, 0, width, height);
            }

            var scale = display.get_monitor_scale (display.get_primary_monitor ());
            success = yield save_image (image, filename, scale, out filename_used);

            if (success) {
                play_shutter_sound ();
            }
        }

        public async void screenshot_area (int x, int y, int width, int height, bool flash, string filename, out bool success, out string filename_used) throws DBusError, IOError {
            yield screenshot_area_with_cursor (x, y, width, height, false, flash, filename, out success, out filename_used);
        }

        public async void screenshot_area_with_cursor (int x, int y, int width, int height, bool include_cursor, bool flash, string filename, out bool success, out string filename_used) throws DBusError, IOError {
            debug ("Taking area screenshot");

            yield wait_stage_repaint ();

            var image = take_screenshot (x, y, width, height, include_cursor);
            unconceal_text ();

            if (flash) {
                flash_area (x, y, width, height);
            }

#if HAS_MUTTER45
            Mtk.Rectangle rect = { x, y, width, height };
#else
            Meta.Rectangle rect = { x, y, width, height };
#endif
            unowned var display = wm.get_display ();
            var scale = display.get_monitor_scale (display.get_monitor_index_for_rect (rect));

            success = yield save_image (image, filename, scale, out filename_used);

            if (success) {
                play_shutter_sound ();
            } else {
                throw new DBusError.FAILED ("Failed to save image");
            }
        }

        public async void screenshot_window (bool include_frame, bool include_cursor, bool flash, string filename, out bool success, out string filename_used) throws DBusError, IOError {
            debug ("Taking window screenshot");

            var window = wm.get_display ().get_focus_window ();
            if (window == null) {
                unconceal_text ();
                throw new DBusError.FAILED ("Cannot find active window");
            }

            var window_actor = (Meta.WindowActor) window.get_compositor_private ();

            float actor_x, actor_y;
            window_actor.get_position (out actor_x, out actor_y);

            var rect = window.get_frame_rect ();
#if HAS_MUTTER45
            if (!include_frame) {
#else
            if ((include_frame && window.is_client_decorated ()) ||
                (!include_frame && !window.is_client_decorated ())) {
#endif
                rect = window.frame_rect_to_client_rect (rect);
            }

#if HAS_MUTTER45
            Mtk.Rectangle clip = { rect.x - (int) actor_x, rect.y - (int) actor_y, rect.width, rect.height };
#else
            Cairo.RectangleInt clip = { rect.x - (int) actor_x, rect.y - (int) actor_y, rect.width, rect.height };
#endif
            var image = (Cairo.ImageSurface) window_actor.get_image (clip);
            if (include_cursor) {
                if (window.get_client_type () == Meta.WindowClientType.WAYLAND) {
                    float resource_scale = window_actor.get_resource_scale ();

                    image.set_device_scale (resource_scale, resource_scale);
                }

                image = composite_stage_cursor (image, { rect.x, rect.y, rect.width, rect.height });
            }

            unconceal_text ();

            if (flash) {
                flash_area (rect.x, rect.y, rect.width, rect.height);
            }

            unowned var display = wm.get_display ();
            var scale = display.get_monitor_scale (display.get_monitor_index_for_rect (rect));

            success = yield save_image (image, filename, scale, out filename_used);

            if (success) {
                play_shutter_sound ();
            }
        }

        public async void select_area (out int x, out int y, out int width, out int height) throws DBusError, IOError {
            var selection_area = new SelectionArea (wm);
            selection_area.closed.connect (() => Idle.add (select_area.callback));
            wm.ui_group.add_child (selection_area);
            selection_area.start_selection ();

            yield;
            selection_area.destroy ();

            if (selection_area.cancelled) {
                throw new GLib.IOError.CANCELLED ("Operation was cancelled");
            }

            yield wait_stage_repaint ();
            var rect = selection_area.get_selection_rectangle ();
            x = (int) GLib.Math.roundf (rect.origin.x);
            y = (int) GLib.Math.roundf (rect.origin.y);
            width = (int) GLib.Math.roundf (rect.size.width);
            height = (int) GLib.Math.roundf (rect.size.height);
        }

        private void unconceal_text () {
            if (conceal_timeout == 0) {
                return;
            }

            desktop_settings.set_string ("font-name", prev_font_regular);
            desktop_settings.set_string ("monospace-font-name", prev_font_mono);
            desktop_settings.set_string ("document-font-name", prev_font_document);

            Source.remove (conceal_timeout);
            conceal_timeout = 0;
        }

        public async void conceal_text () throws DBusError, IOError {
            if (conceal_timeout > 0) {
                Source.remove (conceal_timeout);
            } else {
                prev_font_regular = desktop_settings.get_string ("font-name");
                prev_font_mono = desktop_settings.get_string ("monospace-font-name");
                prev_font_document = desktop_settings.get_string ("document-font-name");

                desktop_settings.set_string ("font-name", "Redacted Script Regular 9");
                desktop_settings.set_string ("monospace-font-name", "Redacted Script Light 10");
                desktop_settings.set_string ("document-font-name", "Redacted Script Regular 10");
            }

            conceal_timeout = Timeout.add (UNCONCEAL_TEXT_TIMEOUT, () => {
                unconceal_text ();
                return Source.REMOVE;
            });
        }

        public async GLib.HashTable<string, Variant> pick_color () throws DBusError, IOError {
            var pixel_picker = new PixelPicker (wm);
            pixel_picker.closed.connect (() => Idle.add (pick_color.callback));
            wm.ui_group.add_child (pixel_picker);
            pixel_picker.start_selection ();

            yield;
            pixel_picker.destroy ();

            if (pixel_picker.cancelled) {
                throw new GLib.IOError.CANCELLED ("Operation was cancelled");
            }

            var picker_point = pixel_picker.point;
            var image = take_screenshot (
                (int) GLib.Math.roundf (picker_point.x),
                (int) GLib.Math.roundf (picker_point.y),
                1, 1,
                false
            );

            assert (image.get_format () == Cairo.Format.ARGB32);

            unowned uchar[] data = image.get_data ();

            double r, g, b;
            if (GLib.ByteOrder.HOST == GLib.ByteOrder.LITTLE_ENDIAN) {
                r = data[2] / 255.0f;
                g = data[1] / 255.0f;
                b = data[0] / 255.0f;
            } else {
                r = data[1] / 255.0f;
                g = data[2] / 255.0f;
                b = data[3] / 255.0f;
            }

            var result = new GLib.HashTable<string, Variant> (str_hash, str_equal);
            result.insert ("color", new GLib.Variant ("(ddd)", r, g, b));

            return result;
        }

        private static string find_target_path () {
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

        private async bool save_image (Cairo.ImageSurface image, string filename, float scale, out string used_filename) {
            return (filename != "")
                ? yield save_image_to_file (image, filename, scale, out used_filename)
                : save_image_to_clipboard (image, filename, out used_filename);
        }

        private static async bool save_image_to_file (Cairo.ImageSurface image, string filename, float scale, out string used_filename) {
            used_filename = filename;

            // We only alter non absolute filename because absolute
            // filename is used for temp clipboard file and shouldn't be changed
            if (!Path.is_absolute (used_filename)) {
                if (!used_filename.has_suffix (EXTENSION)) {
                    used_filename = used_filename.concat (EXTENSION);
                }

                if (scale > 1) {
                    var scale_pos = -EXTENSION.length;
                    used_filename = used_filename.splice (scale_pos, scale_pos, "@%.1gx".printf (scale));
                }

                var path = find_target_path ();
                used_filename = Path.build_filename (path, used_filename, null);
            }

            try {
                var screenshot = Gdk.pixbuf_get_from_surface (image, 0, 0, image.get_width (), image.get_height ());
                var file = File.new_for_path (used_filename);
                FileIOStream stream;
                if (file.query_exists ()) {
                    stream = yield file.open_readwrite_async (FileCreateFlags.NONE);
                } else {
                    stream = yield file.create_readwrite_async (FileCreateFlags.NONE);
                }
                yield screenshot.save_to_stream_async (stream.output_stream, "png");
                return true;
            } catch (GLib.Error e) {
                warning ("could not save file: %s", e.message);
                return false;
            }
        }

        private bool save_image_to_clipboard (Cairo.ImageSurface image, string filename, out string used_filename) {
            used_filename = filename;

            var screenshot = Gdk.pixbuf_get_from_surface (image, 0, 0, image.get_width (), image.get_height ());
            if (screenshot == null) {
                warning ("Could not save screenshot to clipboard: null pixbuf");
                return false;
            }

            uint8[] buffer;
            try {
                screenshot.save_to_buffer (out buffer, "png");
            } catch (Error e) {
                warning ("Could not save screenshot to clipboard: failed to save image to buffer: %s", e.message);
                return false;
            }

            try {
                unowned var selection = wm.get_display ().get_selection ();
                var source = new Meta.SelectionSourceMemory ("image/png", new GLib.Bytes.take (buffer));
                selection.set_owner (Meta.SelectionType.SELECTION_CLIPBOARD, source);
            } catch (Error e) {
                warning ("Could not save screenshot to clipboard: failed to create new Meta.SelectionSourceMemory: %s", e.message);
                return false;
            }

            return true;
        }

        private void play_shutter_sound () {
            Canberra.Context context;
            Canberra.Proplist props;

            Canberra.Context.create (out context);
            Canberra.Proplist.create (out props);

            props.sets (Canberra.PROP_EVENT_ID, "screen-capture");
            props.sets (Canberra.PROP_EVENT_DESCRIPTION, _("Screenshot taken"));
            props.sets (Canberra.PROP_CANBERRA_CACHE_CONTROL, "permanent");

            context.play_full (0, props, null);
        }

        private Cairo.ImageSurface take_screenshot (int x, int y, int width, int height, bool include_cursor) {
            Cairo.ImageSurface image;
            int image_width, image_height;
            float scale;

            wm.stage.get_capture_final_size ({x, y, width, height}, out image_width, out image_height, out scale);

            image = new Cairo.ImageSurface (Cairo.Format.ARGB32, image_width, image_height);

            var paint_flags = include_cursor ? Clutter.PaintFlag.FORCE_CURSORS : Clutter.PaintFlag.NO_CURSORS;

            try {
                if (GLib.ByteOrder.HOST == GLib.ByteOrder.LITTLE_ENDIAN) {
                    wm.stage.paint_to_buffer (
                        {x, y, width, height},
                        scale,
                        image.get_data (),
                        image.get_stride (),
                        Cogl.PixelFormat.BGRA_8888_PRE,
                        paint_flags
                    );
                } else {
                    wm.stage.paint_to_buffer (
                        {x, y, width, height},
                        scale,
                        image.get_data (),
                        image.get_stride (),
                        Cogl.PixelFormat.ARGB_8888_PRE,
                        paint_flags
                    );
                }
            } catch (Error e) {
                warning (e.message);
            }
            return image;
        }

        private Cairo.ImageSurface composite_stage_cursor (Cairo.ImageSurface image, Cairo.RectangleInt image_rect) {
            unowned Meta.CursorTracker cursor_tracker = wm.get_display ().get_cursor_tracker ();
            Graphene.Point coords = {};
            cursor_tracker.get_pointer (out coords, null);

            var region = new Cairo.Region.rectangle (image_rect);
            if (!region.contains_point ((int) coords.x, (int) coords.y)) {
                return image;
            }

            unowned Cogl.Texture texture = cursor_tracker.get_sprite ();
            if (texture == null) {
                return image;
            }

            int width = (int)texture.get_width ();
            int height = (int)texture.get_height ();

            uint8[] data = new uint8[width * height * 4];
            texture.get_data (Cogl.PixelFormat.RGBA_8888, 0, data);

            var cursor_image = new Cairo.ImageSurface.for_data (data, Cairo.Format.ARGB32, width, height, width * 4);
            var target = new Cairo.ImageSurface (Cairo.Format.ARGB32, image_rect.width, image_rect.height);

            var cr = new Cairo.Context (target);
            cr.set_operator (Cairo.Operator.OVER);
            cr.set_source_surface (image, 0, 0);
            cr.paint ();

            cr.set_operator (Cairo.Operator.OVER);
            cr.set_source_surface (cursor_image, coords.x - image_rect.x, coords.y - image_rect.y);
            cr.paint ();

            return (Cairo.ImageSurface)cr.get_target ();
        }

        private async void wait_stage_repaint () {
            ulong signal_id = 0UL;
            signal_id = wm.stage.after_paint.connect (() => {
                wm.stage.disconnect (signal_id);
                Idle.add (wait_stage_repaint.callback);
            });

            wm.stage.queue_redraw ();
            yield;
        }
    }
}
