/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Gala.Plugins.XRDesktop {

    /* 1 pixel/meter = 0.0254 dpi */
    const float XR_PIXELS_PER_METER = 720.0f;
    const float XR_DESKTOP_PLANE_DISTANCE = 3.5f;
    const float XR_LAYER_DISTANCE = 0.1f;
    const float DEFAULT_LEVEL = 0.5f;

    public class Main : Gala.Plugin {
        private Gala.WindowManager? wm = null;
        private DBusService? dbus_service = null;

        private Xrd.Client? xrd_client = null;
        private bool is_enabled { get { return xrd_client != null; } }

        private GL.GLuint cursor_gl_texture;
        private bool is_nvidia = false;
        private int top_layer = 0;
        private Meta.CursorTracker? cursor_tracker = null;

        private static GLib.Mutex upload_xrd_window_mutex = Mutex ();

        public override void initialize (Gala.WindowManager wm) {
            debug ("xrdesktop: Initialize Gala plugin.");
            this.wm = wm;

            try {
                connect_dbus_service ();
            } catch (Error e) {
                critical ("xrdesktop connecting to dbus service failed: %s", e.message);
            }
        }

        public override void destroy () {
            debug ("xrdesktop: Destroy Gala plugin.");
            shutdown_xrdesktop ();
            disconnect_dbus_service ();
        }

        private void connect_dbus_service () throws Error {
            dbus_service = Bus.get_proxy_sync (
                BusType.SESSION,
                "io.elementary.pantheon.XRDesktop",
                "/io/elementary/pantheon/xrdesktop"
            );
            dbus_service.enabled_changed.connect (on_enabled_changed);
        }

        private void disconnect_dbus_service () {
            if (dbus_service != null) {
                dbus_service.enabled_changed.disconnect (on_enabled_changed);
            }
            dbus_service = null;
        }

        private void on_enabled_changed (bool enabled) {
            if (enabled) {
                startup_xrdesktop ();
            } else {
                shutdown_xrdesktop ();
            }
        }

        private void startup_xrdesktop () {
            if (this.xrd_client != null) {
                debug ("xrdesktop: Is already started.");
                return;
            }
            debug ("xrdesktop: Starting mirroring to XR...");

            this.xrd_client = new Xrd.Client ();
            if (this.xrd_client == null) {
                var error_dialog = new Granite.MessageDialog (
                    _("Failed to Mirror Desktop to XR"),
                    _("Usually this is caused by a problem with the VR runtime."),
                    new ThemedIcon ("dialog-error"),
                    Gtk.ButtonsType.CLOSE
                );
                error_dialog.run ();
                error_dialog.destroy ();
                return;
            }

            var gl_vendor = GL.glGetString (GL.GL_VENDOR);
            debug ("xrdesktop: GL_VENDOR = '%s'", gl_vendor);

            cursor_gl_texture = 0;
            is_nvidia = "NVIDIA Corporation" == gl_vendor;

            //initialize_input ();
            mirror_current_windows ();
            arrange_windows_by_desktop_position ();
            connect_signals ();
        }

        private void shutdown_xrdesktop () {
            if (this.xrd_client == null) {
                debug ("xrdesktop: Is already stopped.");
                return;
            }
            debug ("xrdesktop: Stopping mirroring to XR...");
            disconnect_signals ();

             /*
              * We have to clean up windows first because it will only
              * clean up as long as there is an active xrd_client
              * instance
              */
            unowned GLib.SList<Xrd.Window> xrd_windows = xrd_client.get_windows ();
            foreach (var xrd_window in xrd_windows) {
                unowned Window? xr_window = (Window?) xrd_window.native;
                if (xr_window == null) {
                    continue;
                }

                //xr_window.meta_window_actor.paint.disconnect ();
                if (xr_window.gl_textures[0] != 0) {
                    GL.glDeleteTextures (1, xr_window.gl_textures);
                }
                xrd_client.remove_window (xrd_window);
                xrd_window.close ();
            }

            xrd_client = null;
        }

        private void initialize_input () {
            /** TODO:
             * We need a libinputsynth VAPI first,
             * which in turn needs this MR resolved:
             * https://gitlab.freedesktop.org/xrdesktop/libinputsynth/-/merge_requests/3
             */
        }

        private void mirror_current_windows () {
            unowned GLib.List<Meta.WindowActor> window_actors = this.wm.get_display ().get_window_actors ();
            foreach (var window_actor in window_actors) {
                map_window_actor (window_actor);
            }
        }

        private void arrange_windows_by_desktop_position () {
            var meta_windows = new GLib.SList<Meta.Window> ();
            unowned GLib.SList<Xrd.Window> xrd_windows = xrd_client.get_windows ();

            foreach (var xrd_window in xrd_windows) {
                unowned Window? xr_window = (Window?) xrd_window.native;
                if (xr_window == null || xr_window.meta_window_actor == null) {
                    continue;
                }

                var meta_window_actor = xr_window.meta_window_actor;
                var meta_window = meta_window_actor.get_meta_window ();

                if (!is_window_excluded_from_mirroring (meta_window)) {
                    meta_windows.append (meta_window);
                }
            }

            var display = this.wm.get_display ();
            var meta_windows_sorted = display.sort_windows_by_stacking (meta_windows);

            top_layer = 0;
            foreach (var meta_window in meta_windows_sorted) {
                var xrd_window = xrd_client.lookup_window (meta_window);
                if (xrd_window == null) {
                    continue;
                }

                apply_desktop_position (meta_window, xrd_window, top_layer);
                top_layer++;
            }
        }

        private void connect_signals () {
            xrd_client.keyboard_press_event.connect (on_keyboard_press);
            xrd_client.click_event.connect (on_click);
            xrd_client.move_cursor_event.connect (on_move_cursor);
            xrd_client.request_quit_event.connect (on_request_quit);

            this.wm.get_display ().grab_op_begin.connect (on_grab_op_begin);
            this.wm.get_display ().grab_op_end.connect (on_grab_op_end);

            cursor_tracker = this.wm.get_display ().get_cursor_tracker ();
            cursor_tracker.cursor_changed.connect (on_cursor_changed);
        }

        private void disconnect_signals () {
            xrd_client.keyboard_press_event.disconnect (on_keyboard_press);
            xrd_client.click_event.disconnect (on_click);
            xrd_client.move_cursor_event.disconnect (on_move_cursor);
            xrd_client.request_quit_event.disconnect (on_request_quit);

            this.wm.get_display ().grab_op_begin.disconnect (on_grab_op_begin);
            this.wm.get_display ().grab_op_end.disconnect (on_grab_op_end);

            if (cursor_tracker != null) {
                cursor_tracker.cursor_changed.disconnect (on_cursor_changed);
            }
        }

        private void on_keyboard_press (Gdk.Event event) {
            debug ("on_keyboard_press");
        }

        private void on_click (Gdk.Event event) {
            debug ("on_click");
        }

        private void on_move_cursor (Gdk.Event event) {
            debug ("on_move_cursor");
        }

        private void on_request_quit (Gdk.Event event) {
            debug ("Handling XR quit event");
            shutdown_xrdesktop ();
        }

        private void on_grab_op_begin (Meta.Display display, Meta.Window window, Meta.GrabOp grab_op) {
            debug ("on_grab_op_begin");
        }

        private void on_grab_op_end (Meta.Display display, Meta.Window window, Meta.GrabOp grab_op) {
            debug ("on_grab_op_end");
        }

        private void on_cursor_changed () {
            debug ("on_cursor_changed");
        }

        private bool map_window_actor (Meta.WindowActor window_actor) {
            var meta_window = get_validated_window (window_actor);

            if (meta_window == null || is_window_excluded_from_mirroring (meta_window)) {
                return false;
            }

            var rect = meta_window.get_buffer_rect ();
            var is_child = is_child_window (meta_window);

            Meta.WindowActor meta_parent_window_actor = window_actor;
            Meta.Window? meta_parent_window = null;
            Xrd.Window? xrd_parent_window = null;

            if (is_child) {
                if (find_valid_parent_window (meta_window, out meta_parent_window, out xrd_parent_window)) {
                    var xrd_parent_window_data = xrd_parent_window.get_data ();

                    while (xrd_parent_window_data != null && xrd_parent_window_data.child_window != null) {
                        xrd_parent_window = xrd_parent_window_data.parent_window;
                        xrd_parent_window_data = xrd_parent_window.get_data ();

                        unowned Window? xr_window = (Window?) xrd_parent_window.native;
                        if (xr_window != null) {
                            meta_parent_window_actor = xr_window.meta_window_actor;
                            meta_parent_window = meta_parent_window_actor.get_meta_window ();
                        }
                    }
                }
            }

            debug ("xrdesktop: Map window %p: %s (%s)",
                window_actor,
                meta_window.title,
                meta_window.get_description ());

            var xrd_window = Xrd.Window.new_from_pixels (
                xrd_client,
                meta_window.title,
                rect.width,
                rect.height,
                XR_PIXELS_PER_METER);

            var is_draggable = !(is_child && meta_parent_window != null && xrd_parent_window != null);
            xrd_client.add_window (xrd_window, is_draggable, meta_window);

            if (is_child && !is_draggable) {
                var offset = get_offset (meta_parent_window, meta_window);

                xrd_parent_window.add_child (xrd_window, offset);

            } else if (is_child && xrd_parent_window == null) {
                warning ("xrdesktop: Can't add window '%s' as child. No parent candidate!", meta_parent_window.title);
            }

            if (!is_child) {
                apply_desktop_position (meta_window, xrd_window, top_layer);
                top_layer++;
            }

            var xr_window = new Window ();
            xr_window.meta_window_actor = window_actor;
            xrd_window.native = xr_window;

            // Keep xr_window alive by transferring its ownership
            // to xrd_window. It will be freed automatically
            // as soon as xrd_window is freed.
            xrd_window.set_data<Window> ("native-window", xr_window);

            // TODO: We need a way to disconnect this callback,
            // but still pass xrd_window from here somehow
            window_actor.paint.connect ((paint_context) => {
                on_window_actor_paint (window_actor, paint_context, xrd_window);
            });

            return true;
        }

        private Meta.Window? get_validated_window (Meta.WindowActor? window_actor) {
            if (window_actor == null) {
                warning ("xrdesktop: Actor for move cursor not available.");
                return null;
            }

            var window = window_actor.get_meta_window ();
            if (window == null) {
                warning ("xrdesktop: No window to move");
                return null;
            }

            if (window.get_display () == null) {
                warning ("xrdesktop: Window has no display?!");
                return null;
            }

            return window;
        }

        private bool is_window_excluded_from_mirroring (Meta.Window window) {
            var window_type = window.get_type ();

            return window_type == Meta.WindowType.DESKTOP ||
                window_type == Meta.WindowType.DOCK ||
                window_type == Meta.WindowType.DND;
        }

        private bool is_child_window (Meta.Window window) {
            var window_type = window.get_type ();

            return window_type == Meta.WindowType.POPUP_MENU ||
                window_type == Meta.WindowType.DROPDOWN_MENU ||
                window_type == Meta.WindowType.TOOLTIP ||
                window_type == Meta.WindowType.MODAL_DIALOG ||
                window_type == Meta.WindowType.COMBO;
        }

        private bool find_valid_parent_window (Meta.Window child_window,
            out Meta.Window? meta_parent_window,
            out Xrd.Window? xrd_parent_window) {
            /* Try transient first */
            meta_parent_window = child_window.get_transient_for ();
            xrd_parent_window = get_valid_xrd_window (meta_parent_window);
            if (xrd_parent_window != null) {
                return true;
            }

            /* If this doesn't work out try the root ancestor */
            meta_parent_window = child_window.find_root_ancestor ();
            xrd_parent_window = get_valid_xrd_window (meta_parent_window);
            if (xrd_parent_window != null) {
                return true;
            }

            /* Last try, check if anything is focused and make that our parent */
            meta_parent_window = this.wm.get_display ().get_focus_window ();
            xrd_parent_window = get_valid_xrd_window (meta_parent_window);
            if (xrd_parent_window != null) {
                return true;
            }

            /* Didn't find anything */
            warning ("xrdesktop: Could not find a parent for '%s'", child_window.get_title ());

            return false;
        }

        private Xrd.Window? get_valid_xrd_window (Meta.Window? meta_window) {
            if (meta_window == null) {
                return null;
            }

            if (is_window_excluded_from_mirroring (meta_window)) {
                debug ("xrdesktop: Window is excluded from mirroring");
                return null;
            }

            return xrd_client.lookup_window (meta_window);
        }

        private Graphene.Point get_offset (Meta.Window parent, Meta.Window child) {
            var parent_rect = parent.get_buffer_rect ();
            var child_rect = child.get_buffer_rect ();

            var parent_center_x = parent_rect.x + parent_rect.width / 2;
            var parent_center_y = parent_rect.y + parent_rect.height / 2;

            var child_center_x = child_rect.x + child_rect.width / 2;
            var child_center_y = child_rect.y + child_rect.height / 2;

            var offset_x = child_center_x - parent_center_x;
            var offset_y = child_center_y - parent_center_y;

            debug ("xrdesktop: child at %d,%d to parent at %d,%d, offset %d,%d",
                child_center_x,
                child_center_y,
                parent_center_x,
                parent_center_y,
                offset_x,
                offset_y);

            return Graphene.Point () {
                x = offset_x,
                y = - offset_y
            };
        }

        private void apply_desktop_position (Meta.Window meta_window, Xrd.Window xrd_window, int layer) {
            var display = meta_window.get_display ();

            int screen_w, screen_h;
            display.get_size (out screen_w, out screen_h);

            var rect = meta_window.get_buffer_rect ();

            var x = rect.x - screen_h / 2.0f + rect.width / 2.0f;
            var y = screen_h - rect.y - screen_h / 4.0f - rect.height / 2.0f;

            var point = Graphene.Point3D () {
                x = x / XR_PIXELS_PER_METER,
                y = y / XR_PIXELS_PER_METER + DEFAULT_LEVEL,
                z = -XR_DESKTOP_PLANE_DISTANCE + XR_LAYER_DISTANCE * layer
            };

            var transform = Graphene.Matrix ().init_translate (point);
            if (transform != null) {
                xrd_window.set_transformation (transform);
                xrd_window.save_reset_transformation ();
            }
        }


        private void on_window_actor_paint (Meta.WindowActor window_actor,
            Clutter.PaintContext paint_context,
            Xrd.Window xrd_window) {
            upload_xrd_window (xrd_window);
        }

        private bool upload_xrd_window (Xrd.Window xrd_window) {
            unowned Window? xr_window = (Window?) xrd_window.native;
            if (xr_window == null) {
                critical ("xrdesktop: Could not read native Window from XrdWindow.");
                return false;
            }

            var window_actor = xr_window.meta_window_actor;
            var meta_window = get_validated_window (window_actor);
            var rect = meta_window.get_buffer_rect ();

            /* skip upload of small buffers */
            if (rect.width <= 10 && rect.height <= 10) {
                return false;
            }

            var mst = window_actor.get_texture ();
            var gulkan_client = xrd_client.get_gulkan ();

            Cogl.TextureComponents? components = null;
            if (is_nvidia) {
                var cogl_texture = mst.get_texture ();

                if (cogl_texture == null || !cogl_texture.is_texture ()) {
                    critical ("xrdesktop: Could not CoglTexture from MetaShapedTexture.");
                    return false;
                }
                components = cogl_texture.get_components ();
            }

            var ret = false;
            upload_xrd_window_mutex.lock ();
            if (is_nvidia && components == Cogl.TextureComponents.RGB) {
                ret = upload_xrd_window_raw_cairo (gulkan_client, xrd_window, mst, rect);
            } else {
                ret = upload_xrd_window_gl_external_memory (gulkan_client, xrd_window, mst, rect);
            }
            upload_xrd_window_mutex.unlock ();

            return ret;
        }

        private bool upload_xrd_window_raw_cairo (
            Gulkan.Client client,
            Xrd.Window xrd_window,
            Meta.ShapedTexture mst,
            Meta.Rectangle rect
        ) {

            var cairo_rect = Cairo.RectangleInt () {
                x = 0,
                y = 0,
                width = rect.width,
                height = rect.height
            };

            var cairo_surface = mst.get_image (cairo_rect);
            if (cairo_surface == null) {
                critical ("xrdesktop: Could not get Cairo surface from MetaShapedTexture.");
                return false;
            }

            var upload_layout = xrd_client.get_upload_layout ();
            var texture = xrd_window.get_texture ();

            Xrd.render_lock ();
            if (
                rect.width != xrd_window.texture_width ||
                rect.height != xrd_window.texture_height ||
                texture == null
            ) {
                debug ("xrdesktop: Reallocating %dx%d vulkan texture", rect.width, rect.height);
                texture = Gulkan.Texture.new_from_cairo_surface (
                    client,
                    cairo_surface,
                    Vk.Format.B8G8R8A8_SRGB,
                    upload_layout
                );

                if (texture == null) {
                    critical ("xrdesktop: Error creating texture for window!");
                    Xrd.render_unlock ();
                    return false;
                }
                xrd_window.set_and_submit_texture (texture);

            } else {
                texture.upload_cairo_surface (cairo_surface, upload_layout);
                xrd_window.submit_texture ();
            }
            Xrd.render_unlock ();

            return true;
        }

        private bool upload_xrd_window_gl_external_memory (
            Gulkan.Client client,
            Xrd.Window xrd_window,
            Meta.ShapedTexture mst,
            Meta.Rectangle rect
        ) {
            var cogl_texture = mst.get_texture ();

            if (cogl_texture == null || !cogl_texture.is_texture ()) {
                critical ("xrdesktop: Could not get CoglTexture from MetaShapedTexture.");
                return false;
            }

            GL.GLuint meta_tex;
            uint meta_target_uint;
            if (!cogl_texture.get_gl_texture (out meta_tex, out meta_target_uint)) {
                critical ("xrdesktop: Could not get GL handle from CoglTexture.");
                return false;
            }
            GL.GLenum meta_target = (GL.GLenum) meta_target_uint;

            unowned Window? xr_window = (Window?) xrd_window.native;
            if (xr_window == null) {
                critical ("xrdesktop: Could not read native Window from XrdWindow.");
                return false;
            }

            var texture = xrd_window.get_texture ();
            var extent_changed = true;

            if (texture != null) {
                var extent = texture.get_extent ();
                extent_changed = rect.width != extent.width || rect.height != extent.height;
            }

            Xrd.render_lock ();
            if (extent_changed) {
                if (xr_window.gl_textures[0] != 0) {
                    GL.glDeleteTextures (1, xr_window.gl_textures);
                }

                texture = allocate_external_memory (client,
                    meta_tex,
                    meta_target,
                    rect.width,
                    rect.height,
                    xr_window.gl_textures);

                if (texture == null) {
                    critical ("xrdesktop: Error creating texture for window!");
                    Xrd.render_unlock ();
                    return false;
                }

                GL.glCopyImageSubData (
                    meta_tex,
                    meta_target,
                    0,
                    0,
                    0,
                    0,
                    xr_window.gl_textures[0],
                    GL.GL_TEXTURE_2D,
                    0,
                    0,
                    0,
                    0,
                    rect.width,
                    rect.height,
                    1);

                gl_check_error ("glCopyImageSubData");
                GL.glFinish ();

                xrd_window.set_and_submit_texture (texture);

            } else {
                GL.glCopyImageSubData (
                    meta_tex,
                    meta_target,
                    0,
                    0,
                    0,
                    0,
                    xr_window.gl_textures[0],
                    GL.GL_TEXTURE_2D,
                    0,
                    0,
                    0,
                    0,
                    rect.width,
                    rect.height,
                    1
                );

                gl_check_error ("glCopyImageSubData");
                GL.glFinish ();

                xrd_window.set_and_submit_texture (texture);
            }
            Xrd.render_unlock ();

            return true;
        }

        private Gulkan.Texture? allocate_external_memory (
            Gulkan.Client client,
            GL.GLuint source_gl_handle,
            GL.GLenum gl_target,
            int width,
            int height,
            GL.GLuint[]? gl_handle
        ) {
            debug ("xrdesktop: Reallocating %dx%d vulkan texture", width, height);

            /* Get meta texture format */
            GL.glBindTexture (gl_target, source_gl_handle);
            GL.GLint[] internal_format;
            GL.glGetTexLevelParameteriv (GL.GL_TEXTURE_2D, 0, GL.GL_TEXTURE_INTERNAL_FORMAT, out internal_format);

            ulong size;
            int fd;
            var extent = Vk.Extent2D () {
                width = width,
                height = height
            };

            var layout = xrd_client.get_upload_layout ();
            var texture = Gulkan.Texture.new_export_fd (
                client,
                extent,
                Vk.Format.R8G8B8A8_SRGB,
                layout,
                out size,
                out fd
            );

            if (texture == null) {
                critical ("xrdesktop: Unable to initialize Vulkan texture.");
                return null;
            }

            GL.GLuint[] gl_mem_objects = { 0 };
            GL_EXT.glCreateMemoryObjectsEXT (1, gl_mem_objects);
            gl_check_error ("glCreateMemoryObjectsEXT");

            GL.GLint[] gl_dedicated_mem = { 0 };
            GL_EXT.glMemoryObjectParameterivEXT (gl_mem_objects[0], GL_EXT.GL_DEDICATED_MEMORY_OBJECT_EXT, gl_dedicated_mem);
            gl_check_error ("glMemoryObjectParameterivEXT");

            GL_EXT.glGetMemoryObjectParameterivEXT (gl_mem_objects[0], GL_EXT.GL_DEDICATED_MEMORY_OBJECT_EXT, gl_dedicated_mem);
            gl_check_error ("glGetMemoryObjectParameterivEXT");

            GL_EXT.glImportMemoryFdEXT (gl_mem_objects[0], size, GL_EXT.GL_HANDLE_TYPE_OPAQUE_FD_EXT, fd);
            gl_check_error ("glImportMemoryFdEXT");

            GL.glGenTextures (1, gl_handle);
            gl_check_error ("glGenTextures");

            GL.glBindTexture (GL.GL_TEXTURE_2D, gl_handle[0]);
            gl_check_error ("glBindTexture");

            GL.glTexParameteri (GL.GL_TEXTURE_2D, GL_EXT.GL_TEXTURE_TILING_EXT, GL_EXT.GL_OPTIMAL_TILING_EXT);
            gl_check_error ("glTexParameteri GL_TEXTURE_TILING_EXT");

            GL.glTexParameteri (GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MIN_FILTER, GL.GL_LINEAR);
            gl_check_error ("glTexParameteri GL_TEXTURE_MIN_FILTER");

            GL.glTexParameteri (GL.GL_TEXTURE_2D, GL.GL_TEXTURE_MAG_FILTER, GL.GL_LINEAR);
            gl_check_error ("glTexParameteri GL_TEXTURE_MAG_FILTER");

            if (is_nvidia) {
                internal_format = { GL.GL_RGBA8 };
            }

            GL_EXT.glTexStorageMem2DEXT (GL.GL_TEXTURE_2D, 1, internal_format[0], width, height, gl_mem_object[0], 0);
            gl_check_error ("glTexStorageMem2DEXT");

            GL.glFinish ();

            if (!texture.transfer_layout (Vk.ImageLayout.UNDEFINED, Vk.ImageLayout.TRANSFER_SRC_OPTIMAL)) {
                critical ("xrdesktop: Unable to transfer layout.");
            }

            GL_EXT.glDeleteMemoryObjectsEXT (1, gl_mem_object);
            gl_check_error ("glDeleteMemoryObjectsEXT");

            return texture;
        }


        private void gl_check_error (string prefix) {
            GL.GLenum err = GL.GL_NO_ERROR;

            while ((err = GL.glGetError ()) != GL.GL_NO_ERROR) {
                var gl_err_string = "UNKNOWN GL Error";

                switch (err) {
                    case GL.GL_NO_ERROR: gl_err_string = "GL_NO_ERROR GL Error"; break;
                    case GL.GL_INVALID_ENUM: gl_err_string = "GL_INVALID_ENUM GL Error"; break;
                    case GL.GL_INVALID_VALUE: gl_err_string = "GL_INVALID_VALUE GL Error"; break;
                    case GL.GL_INVALID_OPERATION: gl_err_string = "GL_INVALID_OPERATION GL Error"; break;
                    case GL.GL_INVALID_FRAMEBUFFER_OPERATION: gl_err_string = "GL_INVALID_FRAMEBUFFER_OPERATION GL Error"; break;
                    case GL.GL_OUT_OF_MEMORY: gl_err_string = "GL_OUT_OF_MEMORY GL Error"; break;
                    case GL.GL_STACK_UNDERFLOW: gl_err_string = "GL_STACK_UNDERFLOW GL Error"; break;
                    case GL.GL_STACK_OVERFLOW: gl_err_string = "GL_STACK_OVERFLOW GL Error"; break;
                    default:
                        break;
                }

                critical ("xrdesktop: %s - %s", prefix, gl_err_string);
            }
        }
    }
}

public Gala.PluginInfo register_plugin () {
    return {
        "xrdesktop",
        "elementary, Inc. (https://elementary.io)",
        typeof (Gala.Plugins.XRDesktop.Main),
        Gala.PluginFunction.ADDITION,
        Gala.LoadPriority.IMMEDIATE
    };
}
