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
        Gala.WindowManager? wm = null;
        Xrd.Client? xrd_client = null;
        bool is_nvidia = false;
        int top_layer = 0;

        private static GLib.Mutex upload_xrd_window_mutex = Mutex ();

        public override void initialize (Gala.WindowManager wm) {
            this.wm = wm;
            this.xrd_client = new Xrd.Client ();

            if (this.xrd_client == null) {
                error ("Failed to initialize xrdesktop!\nUsually this is caused by a problem with the VR runtime.");
            }

            debug ("== Started xrdesktop ==");
            this.is_nvidia = "NVIDIA Corporation" == GLES2.glGetString (GLES2.GL_VENDOR);

            initialize_input ();
            mirror_current_windows ();
            /*arrange_windows_by_desktop_position ();
            connect_signals ();*/
        }

        public override void destroy () {
            // here you would destroy actors you added to the stage or remove
            // keybindings
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

        private bool map_window_actor (Meta.WindowActor window_actor) {
            var window = get_validated_window (window_actor);

            if (window == null || is_window_excluded_from_mirroring (window)) {
                return false;
            }

            var rect = window.get_buffer_rect ();
            var is_child = is_child_window (window);

            Meta.WindowActor meta_parent_window_actor = window_actor;
            Meta.Window? meta_parent_window = null;
            Xrd.Window? xrd_parent_window = null;

            if (is_child) {
                if (find_valid_parent_window (window, out meta_parent_window, out xrd_parent_window)) {
                    var xrd_parent_window_data = xrd_parent_window.get_data ();

                    while (xrd_parent_window_data != null && xrd_parent_window_data.child_window != null) {
                        xrd_parent_window = xrd_parent_window_data.parent_window;
                        xrd_parent_window_data = xrd_parent_window.get_data ();

                        var gala_xr_window = (Gala.Plugins.XRDesktop.XRWindow?) xrd_parent_window.native;
                        if (gala_xr_window != null && gala_xr_window.meta_window_actor != null) {
                            meta_parent_window_actor = gala_xr_window.meta_window_actor;
                            meta_parent_window = meta_parent_window_actor.get_meta_window ();
                        }
                    }
                }
            }

            debug ("Map window %p: %s (%s)",
                meta_parent_window_actor,
                meta_parent_window.title,
                meta_parent_window.get_description ());

            var xrd_window = Xrd.Window.new_from_pixels (
                xrd_client,
                meta_parent_window.title,
                rect.width,
                rect.height,
                XR_PIXELS_PER_METER);

            var is_draggable = !(is_child && meta_parent_window != null && xrd_parent_window != null);
            xrd_client.add_window (xrd_window, is_draggable, meta_parent_window);

            if (is_child && !is_draggable) {
                var offset = get_offset (meta_parent_window, window);

                xrd_parent_window.add_child (xrd_window, offset);

            } else if (is_child && xrd_parent_window == null) {
                warning ("Can't add window '%s' as child. No parent candidate!", meta_parent_window.title);
            }

            if (!is_child) {
                apply_desktop_position (meta_parent_window, xrd_parent_window, top_layer);
                top_layer++;
            }

            var xr_window = new XRWindow ();
            xr_window.meta_window_actor = window_actor;
            xr_window.gl_texture = null;

            xrd_window.native = xr_window;
            window_actor.paint.connect ((paint_context) => {
                on_window_actor_paint (window_actor, paint_context, xrd_window);
            });

            return true;
        }

        private Meta.Window? get_validated_window (Meta.WindowActor? window_actor) {
            if (window_actor == null) {
                warning ("Actor for move cursor not available.");
                return null;
            }

            var window = window_actor.get_meta_window ();
            if (window == null) {
                warning ("No window to move");
                return null;
            }

            if (window.get_display () == null) {
                warning ("Window has no display?!");
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
            warning ("Could not find a parent for '%s'", child_window.get_title ());

            return false;
        }

        private Xrd.Window? get_valid_xrd_window (Meta.Window? meta_window) {
            if (meta_window == null) {
                return null;
            }

            if (is_window_excluded_from_mirroring (meta_window)) {
                debug ("Window is excluded from mirroring");
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

            debug ("child at %d,%d to parent at %d,%d, offset %d,%d",
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
            xrd_window.set_transformation (transform);
            xrd_window.save_reset_transformation ();
        }


        private void on_window_actor_paint (Meta.WindowActor window_actor,
            Clutter.PaintContext paint_context,
            Xrd.Window xrd_window) {
            upload_xrd_window (xrd_window);
        }

        private bool upload_xrd_window (Xrd.Window xrd_window) {
            var xr_window = (XRWindow?) xrd_window.native;
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
                    error ("Could not CoglTexture from MetaShapedTexture.");
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

        private bool upload_xrd_window_raw_cairo (Gulkan.Client client,
            Xrd.Window xrd_window,
            Meta.ShapedTexture mst,
            Meta.Rectangle rect) {

            var cairo_rect = Cairo.RectangleInt () {
                x = 0,
                y = 0,
                width = rect.width,
                height = rect.height
            };

            var cairo_surface = mst.get_image (cairo_rect);
            if (cairo_surface == null) {
                error ("Could not get Cairo surface from MetaShapedTexture.");
                return false;
            }

            var xr_window = (XRWindow) xrd_window.native;
            var upload_layout = xrd_client.get_upload_layout ();
            var texture = xrd_window.get_texture ();

            Xrd.render_lock ();
            if (
                rect.width != xrd_window.texture_width ||
                rect.height != xrd_window.texture_height ||
                texture == null
            ) {
                debug ("Reallocating %dx%d vulkan texture", rect.width, rect.height);
                texture = Gulkan.Texture.new_from_cairo_surface (
                    client,
                    cairo_surface,
                    Vk.Format.B8G8R8A8_SRGB,
                    upload_layout
                );

                if (!Gulkan.is_texture (texture)) {
                    error ("Error creating texture for window!");
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

        private bool upload_xrd_window_gl_external_memory (Gulkan.Client client,
            Xrd.Window xrd_window,
            Meta.ShapedTexture mst,
            Meta.Rectangle rect) {
            var cogl_texture = mst.get_texture ();

            if (cogl_texture == null || !cogl_texture.is_texture ()) {
                error ("Could not get CoglTexture from MetaShapedTexture.");
                return false;
            }

            GLES2.GLuint meta_tex;
            uint meta_target_uint;
            if (!cogl_texture.get_gl_texture (out meta_tex, out meta_target_uint)) {
                error ("Could not get GL handle from CoglTexture.");
                return false;
            }
            GLES2.GLenum meta_target = (GLES2.GLenum) meta_target_uint;

            var xr_window = (XRWindow) xrd_window.native;
            var texture = xrd_window.get_texture ();
            var extent_changed = true;

            if (texture != null) {
                var extent = texture.get_extent ();
                extent_changed = rect.width != extent.width || rect.height != extent.height;
            }

            Xrd.render_lock ();

            if (extent_changed) {
                if (xr_window.gl_texture != null) {
                    GLES2.glDeleteTextures (1, xr_window.gl_texture);
                }

                texture = allocate_external_memory (client,
                    meta_tex,
                    meta_target,
                    rect.width,
                    rect.height,
                    out xr_window.gl_texture);

                /*
                if (!GULKAN_IS_TEXTURE (texture))
                {
                g_printerr ("Error creating texture for window!\n");
                xrd_render_unlock ();
                return FALSE;
                }

            _glCopyImageSubData (meta_tex, meta_target, 0, 0, 0, 0,
                                shell_win->gl_texture, GL_TEXTURE_2D, 0, 0, 0, 0,
                                rect->width, rect->height, 1);
            gl_check_error ("_glCopyImageSubData");
            _glFinish ();
            xrd_window_set_and_submit_texture (xrd_win, texture);
                */

            } else {
                /*GLES2.glCopyImageSubData (
                    meta_tex,
                    meta_target,
                    0,
                    0,
                    0,
                    0,
                    cursor_gl_texture,
                    GL_TEXTURE_2D,
                    0,
                    0,
                    0,
                    0,
                    cursor_width,
                    cursor_height,
                    1
                );*/

                GLES2.glFinish ();
                // xrd_desktop_cursor_submit_texture (cursor);
            }

            Xrd.render_unlock ();
            return false;
        }

        private Gulkan.Texture? allocate_external_memory (
            Gulkan.Client client,
            GLES2.GLuint source_gl_handle,
            GLES2.GLenum gl_target,
            int width,
            int height,
            out GLES2.GLuint* gl_handle
        ) {
            debug ("Reallocating %dx%d vulkan texture", width, height);

            /* Get meta texture format */
            GLES2.glBindTexture (gl_target, source_gl_handle);
            GLES2.GLint internal_format;
            /*GLint internal_format;
            _glGetTexLevelParameteriv (GL_TEXTURE_2D, 0,
                                        GL_TEXTURE_INTERNAL_FORMAT, &internal_format);*/
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
                error ("Unable to initialize Vulkan texture.");
                return null;
            }

            var gl_dedicated_mem = GLES2.GL_TRUE;
            GLES2.GLuint gl_mem_object;

/*
  _glCreateMemoryObjectsEXT (1, &gl_mem_object);
  gl_check_error ("_glCreateMemoryObjectsEXT");

  _glMemoryObjectParameterivEXT (gl_mem_object,
                                 GL_DEDICATED_MEMORY_OBJECT_EXT,
                                &gl_dedicated_mem);
  gl_check_error ("_glMemoryObjectParameterivEXT");

  _glGetMemoryObjectParameterivEXT (gl_mem_object,
                                    GL_DEDICATED_MEMORY_OBJECT_EXT,
                                   &gl_dedicated_mem);
  gl_check_error ("_glGetMemoryObjectParameterivEXT");

  _glImportMemoryFdEXT (gl_mem_object, size,
                        GL_HANDLE_TYPE_OPAQUE_FD_EXT, fd);
  gl_check_error ("_glImportMemoryFdEXT");

  _glGenTextures (1, out_gl_handle);
  gl_check_error ("_glGenTextures");

  _glBindTexture (GL_TEXTURE_2D, *out_gl_handle);
  gl_check_error ("_glBindTexture");

  _glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_TILING_EXT, GL_OPTIMAL_TILING_EXT);
  gl_check_error ("glTexParameteri GL_TEXTURE_TILING_EXT");
  _glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  gl_check_error ("glTexParameteri GL_TEXTURE_MIN_FILTER");
  _glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  gl_check_error ("glTexParameteri GL_TEXTURE_MAG_FILTER");

  if (self->nvidia)
    internal_format = GL_RGBA8;

  _glTexStorageMem2DEXT (GL_TEXTURE_2D, 1, internal_format,
                         width, height, gl_mem_object, 0);
  gl_check_error ("_glTexStorageMem2DEXT");

  _glFinish ();

  if (!gulkan_texture_transfer_layout (texture,
                                       VK_IMAGE_LAYOUT_UNDEFINED,
                                       VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL))
    {
      g_printerr ("Unable to transfer layout.\n");
    }

  _glDeleteMemoryObjectsEXT (1, &gl_mem_object);
  gl_check_error ("_glDeleteMemoryObjectsEXT");

  return texture;
} */
            return null;
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
