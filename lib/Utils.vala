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

namespace Gala {
    public class Utils {
        private struct CachedIcon {
            public Gdk.Pixbuf icon;
            public int icon_size;
            public int scale;
        }

        private static Gee.HashMap<int, Gdk.Pixbuf?>? resize_pixbufs = null;
        private static Gee.HashMap<int, Gdk.Pixbuf?>? close_pixbufs = null;

        private static Gee.HashMultiMap<DesktopAppInfo, CachedIcon?> icon_cache;
        private static Gee.HashMap<Meta.Window, DesktopAppInfo> window_to_desktop_cache;
        private static Gee.ArrayList<CachedIcon?> unknown_icon_cache;

        private static AppCache app_cache;

        static construct {
            icon_cache = new Gee.HashMultiMap<DesktopAppInfo, CachedIcon?> ();
            window_to_desktop_cache = new Gee.HashMap<Meta.Window, DesktopAppInfo> ();
            unknown_icon_cache = new Gee.ArrayList<CachedIcon?> ();

            app_cache = new AppCache ();
            app_cache.changed.connect (() => {
                icon_cache.clear ();
                window_to_desktop_cache.clear ();
            });
        }

        public static Gdk.Pixbuf get_icon_for_window (Meta.Window window, int icon_size, int scale) {
            var transient_for = window.get_transient_for ();
            if (transient_for != null) {
                return get_icon_for_window (transient_for, icon_size, scale);
            }

            GLib.DesktopAppInfo? desktop_app = null;
            desktop_app = window_to_desktop_cache[window];
            if (desktop_app != null) {
                var icon = get_icon_for_desktop_app_info (desktop_app, icon_size, scale);
                if (icon != null) {
                    return icon;
                }
            }

            var sandbox_id = window.get_sandboxed_app_id ();

            var wm_instance = window.get_wm_class_instance ();
            desktop_app = app_cache.lookup_startup_wmclass (wm_instance);
            if (desktop_app != null && check_app_prefix (desktop_app, sandbox_id)) {
                var icon = get_icon_for_desktop_app_info (desktop_app, icon_size, scale);
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            var wm_class = window.get_wm_class ();
            desktop_app = app_cache.lookup_startup_wmclass (wm_class);
            if (desktop_app != null && check_app_prefix (desktop_app, sandbox_id)) {
                var icon = get_icon_for_desktop_app_info (desktop_app, icon_size, scale);
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            desktop_app = lookup_desktop_wmclass (wm_instance);
            if (desktop_app != null && check_app_prefix (desktop_app, sandbox_id)) {
                var icon = get_icon_for_desktop_app_info (desktop_app, icon_size, scale);
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            desktop_app = lookup_desktop_wmclass (wm_class);
            if (desktop_app != null && check_app_prefix (desktop_app, sandbox_id)) {
                var icon = get_icon_for_desktop_app_info (desktop_app, icon_size, scale);
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            desktop_app = get_app_from_id (sandbox_id);
            if (desktop_app != null) {
                var icon = get_icon_for_desktop_app_info (desktop_app, icon_size, scale);
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            var gapplication_id = window.get_gtk_application_id ();
            desktop_app = get_app_from_id (gapplication_id);
            if (desktop_app != null) {
                var icon = get_icon_for_desktop_app_info (desktop_app, icon_size, scale);
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            unowned Meta.Group group = window.get_group ();
            if (group != null) {
                var group_windows = group.list_windows ();
                group_windows.foreach ((window) => {
                    if (window.get_window_type () != Meta.WindowType.NORMAL) {
                        return;
                    }

                    if (window_to_desktop_cache[window] != null) {
                        desktop_app = window_to_desktop_cache[window];
                    }
                });

                if (desktop_app != null) {
                    var icon = get_icon_for_desktop_app_info (desktop_app, icon_size, scale);
                    if (icon != null) {
                        window_to_desktop_cache[window] = desktop_app;
                        return icon;
                    }
                }
            }

            // Haven't been able to get an icon for the window at this point, look to see
            // if we've already cached "application-default-icon" at this size
            foreach (var icon in unknown_icon_cache) {
                if (icon.icon_size == icon_size && icon.scale == scale) {
                    return icon.icon;
                }
            }

            // Construct a new "application-default-icon" and store it in the cache
            try {
                var icon = Gtk.IconTheme.get_default ().load_icon_for_scale ("application-default-icon", icon_size, scale, 0);
                unknown_icon_cache.add (CachedIcon () { icon = icon, icon_size = icon_size, scale = scale });
                return icon;
            } catch (Error e) {
                var icon = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, icon_size * scale, icon_size * scale);
                icon.fill (0x00000000);
                return icon;
            }
        }

        private static bool check_app_prefix (GLib.DesktopAppInfo app, string? sandbox_id) {
            if (sandbox_id == null) {
                return true;
            }

            var prefix = "%s.".printf (sandbox_id);

            if (app.get_id ().has_prefix (prefix)) {
                return true;
            }

            return false;
        }

        public static void clear_window_cache (Meta.Window window) {
            var desktop = window_to_desktop_cache[window];
            if (desktop != null) {
                icon_cache.remove_all (desktop);
                window_to_desktop_cache.unset (window);
            }
        }

        private static GLib.DesktopAppInfo? get_app_from_id (string? id) {
            if (id == null) {
                return null;
            }

            var desktop_file = "%s.desktop".printf (id);
            return app_cache.lookup_id (desktop_file);
        }

        private static GLib.DesktopAppInfo? lookup_desktop_wmclass (string? wm_class) {
            if (wm_class == null) {
                return null;
            }

            var desktop_info = get_app_from_id (wm_class);

            if (desktop_info != null) {
                return desktop_info;
            }

            var canonicalized = wm_class.ascii_down ().delimit (" ", '-');
            return get_app_from_id (canonicalized);
        }

        private static Gdk.Pixbuf? get_icon_for_desktop_app_info (GLib.DesktopAppInfo desktop, int icon_size, int scale) {
            if (icon_cache.contains (desktop)) {
                foreach (var icon in icon_cache[desktop]) {
                    if (icon.icon_size == icon_size && icon.scale == scale) {
                        return icon.icon;
                    }
                }
            }

            var icon = desktop.get_icon ();

            if (icon is GLib.ThemedIcon) {
                var icon_names = ((GLib.ThemedIcon)icon).get_names ();
                var icon_info = Gtk.IconTheme.get_default ().choose_icon_for_scale (icon_names, icon_size, scale, 0);

                if (icon_info == null) {
                    return null;
                }

                try {
                    var pixbuf = icon_info.load_icon ();
                    icon_cache.@set (desktop, CachedIcon () { icon = pixbuf, icon_size = icon_size, scale = scale });
                    return pixbuf;
                } catch (Error e) {
                    return null;
                }
            } else if (icon is GLib.FileIcon) {
                var file = ((GLib.FileIcon)icon).file;
                var size_with_scale = icon_size * scale;
                try {
                    var pixbuf = new Gdk.Pixbuf.from_stream_at_scale (file.read (), size_with_scale, size_with_scale, true);
                    icon_cache.@set (desktop, CachedIcon () { icon = pixbuf, icon_size = icon_size, scale = scale });
                    return pixbuf;
                } catch (Error e) {
                    return null;
                }
            }

            return null;
        }

        /**
         * Multiplies an integer by a floating scaling factor, and then
         * returns the result rounded to the nearest integer
         */
         public static int scale_to_int (int value, float scale_factor) {
            return (int) (Math.round ((float)value * scale_factor));
        }

        /**
         * Get the number of toplevel windows on a workspace excluding those that are
         * on all workspaces
         *
         * @param workspace The workspace on which to count the windows
         */
        public static uint get_n_windows (Meta.Workspace workspace) {
            var n = 0;
            foreach (weak Meta.Window window in workspace.list_windows ()) {
                if (window.on_all_workspaces)
                    continue;
                if (
                    window.window_type == Meta.WindowType.NORMAL ||
                    window.window_type == Meta.WindowType.DIALOG ||
                    window.window_type == Meta.WindowType.MODAL_DIALOG)
                    n ++;
            }

            return n;
        }

        /**
         * Creates an actor showing the current contents of the given WindowActor.
         *
         * @param actor      The actor from which to create a snapshot
         * @param inner_rect The inner (actually visible) rectangle of the window
         * @param outer_rect The outer (input region) rectangle of the window
         *
         * @return           A copy of the actor at that time or %NULL
         */
        public static Clutter.Actor? get_window_actor_snapshot (
            Meta.WindowActor actor,
            Meta.Rectangle inner_rect
        ) {
            Clutter.Content content;

            try {
                content = actor.paint_to_content (inner_rect);
            } catch (Error e) {
                warning ("Could not create window snapshot: %s", e.message);
                return null;
            }

            if (content == null) {
                warning ("Could not create window snapshot");
                return null;
            }

            var container = new Clutter.Actor ();
            container.set_size (inner_rect.width, inner_rect.height);
            container.content = content;

            return container;
        }

        /**
         * DEPRECATED: When used with Mutter 44, this will always return 1.
         * Get the scaling factor for the monitor you are drawing to with
         * `Meta.Display.get_monitor_scale` instead
         */
        [Version (deprecated = true, deprecated_since = "7.0.3", replacement = "Meta.Display.get_monitor_scale")]
        public static int get_ui_scaling_factor () {
#if HAS_MUTTER44
            return 1;
#else
            return Meta.Backend.get_backend ().get_settings ().get_ui_scaling_factor ();
#endif
        }

        /**
         * Returns the pixbuf that is used for close buttons throughout gala at a
         * size of 36px
         *
         * @return the close button pixbuf or null if it failed to load
         */
        public static Gdk.Pixbuf? get_close_button_pixbuf (float scale) {
            var height = scale_to_int (36, scale);

            if (close_pixbufs == null) {
                close_pixbufs = new Gee.HashMap<int, Gdk.Pixbuf?> ();
            }

            if (close_pixbufs[height] == null) {
                try {
                    close_pixbufs[height] = new Gdk.Pixbuf.from_resource_at_scale (
                        Config.RESOURCEPATH + "/buttons/close.svg",
                        -1,
                        height,
                        true
                    );
                } catch (Error e) {
                    warning (e.message);
                    return null;
                }
            }

            return close_pixbufs[height];
        }

        /**
         * Creates a new reactive ClutterActor at 36px with the close pixbuf
         *
         * @return The close button actor
         */
        public static Clutter.Actor create_close_button (float scale) {
            var texture = new Clutter.Actor ();
            var pixbuf = get_close_button_pixbuf (scale);

            texture.reactive = true;

            if (pixbuf != null) {
                try {
                    var image = new Clutter.Image ();
                    Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
                    image.set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);
                    texture.set_content (image);
                    texture.set_size (pixbuf.width, pixbuf.height);
                } catch (Error e) {}
            } else {
                // we'll just make this red so there's at least something as an
                // indicator that loading failed. Should never happen and this
                // works as good as some weird fallback-image-failed-to-load pixbuf
                texture.set_size (scale_to_int (36, scale), scale_to_int (36, scale));
                texture.background_color = { 255, 0, 0, 255 };
            }

            return texture;
        }
        /**
         * Returns the pixbuf that is used for resize buttons throughout gala at a
         * size of 36px
         *
         * @return the close button pixbuf or null if it failed to load
         */
        public static Gdk.Pixbuf? get_resize_button_pixbuf (float scale) {
            var height = scale_to_int (36, scale);

            if (resize_pixbufs == null) {
                resize_pixbufs = new Gee.HashMap<int, Gdk.Pixbuf?> ();
            }

            if (resize_pixbufs[height] == null) {
                try {
                    resize_pixbufs[height] = new Gdk.Pixbuf.from_resource_at_scale (
                        Config.RESOURCEPATH + "/buttons/resize.svg",
                        -1,
                        height,
                        true
                    );
                } catch (Error e) {
                    warning (e.message);
                    return null;
                }
            }

            return resize_pixbufs[height];
        }

        /**
         * Creates a new reactive ClutterActor at 36px with the resize pixbuf
         *
         * @return The resize button actor
         */
        public static Clutter.Actor create_resize_button (float scale) {
            var texture = new Clutter.Actor ();
            var pixbuf = get_resize_button_pixbuf (scale);

            texture.reactive = true;

            if (pixbuf != null) {
                try {
                    var image = new Clutter.Image ();
                    Cogl.PixelFormat pixel_format = (pixbuf.get_has_alpha () ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888);
                    image.set_data (pixbuf.get_pixels (), pixel_format, pixbuf.width, pixbuf.height, pixbuf.rowstride);
                    texture.set_content (image);
                    texture.set_size (pixbuf.width, pixbuf.height);
                } catch (Error e) {}
            } else {
                // we'll just make this red so there's at least something as an
                // indicator that loading failed. Should never happen and this
                // works as good as some weird fallback-image-failed-to-load pixbuf
                var size = scale_to_int (36, scale);
                texture.set_size (size, size);
                texture.background_color = { 255, 0, 0, 255 };
            }

            return texture;
        }

        private static Gtk.CssProvider gala_css = null;
        public static unowned Gtk.CssProvider? get_gala_css () {
            if (gala_css == null) {
                gala_css = new Gtk.CssProvider ();
                gala_css.load_from_resource ("/io/elementary/desktop/gala/gala.css");
            }

            return gala_css;
        }
    }
}
