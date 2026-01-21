/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2016 Rico Tzschichholz
 *                         2016 Santiago León O.
 *                         2025 elementary, Inc. (https://elementary.io)
 */

[DBus (name="org.gnome.Shell.Screenshot")]
public class Gala.ScreenshotManager : Object {
    private const string EXTENSION = ".png";
    private const int UNCONCEAL_TEXT_TIMEOUT = 2000;

    [DBus (visible = false)]
    public WindowManager wm { get; construct; }
    [DBus (visible = false)]
    public NotificationsManager notifications_manager { get; construct; }
    [DBus (visible = false)]
    public FilterManager filter_manager { get; construct; }

    private bool? _is_redacted_font_available = null;
    private bool is_redacted_font_available {
        get {
            if (_is_redacted_font_available != null) {
                return _is_redacted_font_available;
            }

            (unowned Pango.FontFamily)[] families;
            Pango.CairoFontMap.get_default ().list_families (out families);

            _is_redacted_font_available = false;
            foreach (unowned var family in families) {
                if (family.get_name () == "Redacted Script") {
                    _is_redacted_font_available = true;
                    break;
                }
            }

            return _is_redacted_font_available;
        }
    }

    private Settings desktop_settings;
    private GLib.HashTable<uint32, string?> notifications_id_to_path;

    private string prev_font_regular;
    private string prev_font_document;
    private string prev_font_mono;
    private uint conceal_timeout;

    public ScreenshotManager (WindowManager wm, NotificationsManager notifications_manager, FilterManager filter_manager) {
        Object (wm: wm, notifications_manager: notifications_manager, filter_manager: filter_manager);
    }

    construct {
        desktop_settings = new Settings ("org.gnome.desktop.interface");
        notifications_id_to_path = new GLib.HashTable<uint32, string> (GLib.direct_hash, GLib.direct_equal);

        var keybinding_settings = new GLib.Settings ("io.elementary.desktop.wm.keybindings");
        unowned var display = wm.get_display ();
        display.add_keybinding ("screenshot", keybinding_settings, IGNORE_AUTOREPEAT, handle_screenshot);
        display.add_keybinding ("interactive-screenshot", keybinding_settings, IGNORE_AUTOREPEAT, handle_screenshot);
        display.add_keybinding ("window-screenshot", keybinding_settings, IGNORE_AUTOREPEAT, handle_screenshot);
        display.add_keybinding ("area-screenshot", keybinding_settings, IGNORE_AUTOREPEAT, handle_screenshot);
        display.add_keybinding ("screenshot-clip", keybinding_settings, IGNORE_AUTOREPEAT, handle_screenshot);
        display.add_keybinding ("window-screenshot-clip", keybinding_settings, IGNORE_AUTOREPEAT, handle_screenshot);
        display.add_keybinding ("area-screenshot-clip", keybinding_settings, IGNORE_AUTOREPEAT, handle_screenshot);

        notifications_manager.action_invoked.connect (handle_action_invoked);
        notifications_manager.notification_closed.connect ((id) => notifications_id_to_path.remove (id));
    }

    private void handle_screenshot (
        Meta.Display display, Meta.Window? window, Clutter.KeyEvent? event, Meta.KeyBinding binding
    ) {
        switch (binding.get_name ()) {
            case "screenshot":
                handle_screenshot_screen_shortcut.begin (false);
                break;
            case "interactive-screenshot":
                wm.launch_action (ActionKeys.INTERACTIVE_SCREENSHOT_ACTION);
                break;
            case "area-screenshot":
                handle_screenshot_area_shortcut.begin (false);
                break;
            case "window-screenshot":
                handle_screenshot_current_window_shortcut.begin (false);
                break;
            case "screenshot-clip":
                handle_screenshot_screen_shortcut.begin (true);
                break;
            case "area-screenshot-clip":
                handle_screenshot_area_shortcut.begin (true);
                break;
            case "window-screenshot-clip":
                handle_screenshot_current_window_shortcut.begin (true);
                break;
        }
    }

    private string generate_screenshot_filename () {
        var date_time = new GLib.DateTime.now_local ().format ("%Y-%m-%d %H.%M.%S");
        /// TRANSLATORS: %s represents a timestamp here
        return _("Screenshot from %s").printf (date_time);
    }

    private async void handle_screenshot_screen_shortcut (bool clipboard) {
        try {
            string filename = clipboard ? "" : generate_screenshot_filename ();
            bool success = false;
            string filename_used = "";
            yield screenshot (false, true, filename, out success, out filename_used);

            if (success) {
                send_screenshot_notification.begin (filename_used);
            }
        } catch (Error e) {
            warning (e.message);
        }
    }

    private async void handle_screenshot_area_shortcut (bool clipboard) {
        try {
            string filename = clipboard ? "" : generate_screenshot_filename ();
            bool success = false;
            string filename_used = "";

            int x, y, w, h;
            yield select_area (out x, out y, out w, out h);
            yield screenshot_area (x, y, w, h, true, filename, out success, out filename_used);

            if (success) {
                send_screenshot_notification.begin (filename_used);
            }
        } catch (Error e) {
            warning (e.message);
        }
    }

    [DBus (visible = false)]
    public async void handle_screenshot_current_window_shortcut (bool clipboard) {
        try {
            string filename = clipboard ? "" : generate_screenshot_filename ();
            bool success = false;
            string filename_used = "";
            yield screenshot_window (true, false, true, filename, out success, out filename_used);

            if (success) {
                send_screenshot_notification.begin (filename_used);
            }
        } catch (Error e) {
            warning (e.message);
        }
    }

    private async void send_screenshot_notification (string filename_used) {
        var clipboard = filename_used == "";

        string[] actions = {};
        if (!clipboard) {
            var files_appinfo = AppInfo.get_default_for_type ("inode/directory", true);

            actions = {
                "default",
                "",

                "show-in-files",
                /// TRANSLATORS: %s represents a name of file manager
                _("Show in %s").printf (files_appinfo.get_display_name ())
            };
        }

        var notification_id = yield notifications_manager.send (
            "ScreenshotManager",
            "image-x-generic",
            _("Screenshot taken"),
            clipboard ? _("Screenshot is saved to clipboard") : _("Screenshot saved to screenshots folder"),
            actions,
            new GLib.HashTable<string, Variant> (null, null)
        );

        if (notification_id != null && !clipboard) {
            notifications_id_to_path[notification_id] = filename_used;
        }
    }

    private void handle_action_invoked (uint32 id, string name, GLib.Variant? target_value) {
        var path = notifications_id_to_path[id];
        if (path == null) {
            return;
        }

        switch (name) {
            case "default":
                open_in_photo_viewer (path);
                break;
            case "show-in-files":
                show_in_files (path);
                break;
        }
    }

    private void open_in_photo_viewer (string path) {
        var files_list = new GLib.List<GLib.File> ();
        files_list.append (GLib.File.new_for_path (path));

        var photos_appinfo = AppInfo.get_default_for_type ("image/png", true);

        try {
            photos_appinfo.launch (files_list, null);
        } catch (Error e) {
            warning (e.message);
        }
    }

    private void show_in_files (string path) {
        var files_list = new GLib.List<GLib.File> ();
        files_list.append (GLib.File.new_for_path (path));

        var files_appinfo = AppInfo.get_default_for_type ("inode/directory", true);

        try {
            files_appinfo.launch (files_list, null);
        } catch (Error e) {
            warning (e.message);
        }
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
        flash_actor.set_background_color (Cogl.Color.from_string ("#FFFFFF"));
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

        filter_manager.pause_for_screenshot = true;

        yield wait_stage_repaint ();

        var image = take_screenshot (0, 0, width, height, include_cursor);
        unconceal_text ();
        filter_manager.pause_for_screenshot = false;

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

        filter_manager.pause_for_screenshot = true;

        yield wait_stage_repaint ();

        var image = take_screenshot (x, y, width, height, include_cursor);
        unconceal_text ();
        filter_manager.pause_for_screenshot = false;

        if (flash) {
            flash_area (x, y, width, height);
        }

        Mtk.Rectangle rect = { x, y, width, height };
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

        var rect = window.get_buffer_rect ();
        if (!include_frame) {
            rect = window.get_frame_rect ();
        }

        Mtk.Rectangle clip = { rect.x - (int) window_actor.x, rect.y - (int) window_actor.y, rect.width, rect.height };
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
        if (!is_redacted_font_available || conceal_timeout == 0) {
            return;
        }

        desktop_settings.set_string ("font-name", prev_font_regular);
        desktop_settings.set_string ("monospace-font-name", prev_font_mono);
        desktop_settings.set_string ("document-font-name", prev_font_document);

        Source.remove (conceal_timeout);
        conceal_timeout = 0;
    }

    public async void conceal_text () throws DBusError, IOError {
        if (!is_redacted_font_available) {
            throw new DBusError.FAILED ("Redacted font is not installed.");
        }

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
            var screenshot = pixbuf_from_surface (image);
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

        var screenshot = pixbuf_from_surface (image);
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
        wm.get_display ().get_sound_player ().play_from_theme ("screen-capture", _("Screenshot taken"));
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
#if HAS_MUTTER48
        unowned var cursor_tracker = wm.get_display ().get_compositor ().get_backend ().get_cursor_tracker ();
#else
        unowned var cursor_tracker = wm.get_display ().get_cursor_tracker ();
#endif
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

        return (Cairo.ImageSurface) cr.get_target ();
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

    private static Gdk.Pixbuf pixbuf_from_surface (Cairo.ImageSurface image) {
        var width = image.get_width ();
        var height = image.get_height ();

        var pixbuf = new Gdk.Pixbuf (RGB, true, 8, width, height);

        unowned var src_data = image.get_data ();
        unowned var dest_data = pixbuf.get_pixels ();

        for (var y = 0; y < height; y++) {
            var row_start = y * width * 4;

            for (var x = 0; x < width; x++) {
                var pixel_start = row_start + x * 4;
                var alpha = src_data[pixel_start + 3];

                if (alpha == 0) {
                    dest_data[pixel_start + 0] = 0;
                    dest_data[pixel_start + 1] = 0;
                    dest_data[pixel_start + 2] = 0;
                } else {
                    dest_data[pixel_start + 0] = (src_data[pixel_start + 2] * 255 + alpha / 2) / alpha;
                    dest_data[pixel_start + 1] = (src_data[pixel_start + 1] * 255 + alpha / 2) / alpha;
                    dest_data[pixel_start + 2] = (src_data[pixel_start + 0] * 255 + alpha / 2) / alpha;
                }

                dest_data[pixel_start + 3] = alpha;
                
            }
        }

        return pixbuf;
    }
}
