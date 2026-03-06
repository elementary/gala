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
        public const int BUTTON_SIZE = 36;

        private static Gee.HashMap<Meta.Window, DesktopAppInfo> window_to_desktop_cache;

        private static AppCache app_cache;

        static construct {
            window_to_desktop_cache = new Gee.HashMap<Meta.Window, DesktopAppInfo> ();

            app_cache = new AppCache ();
            app_cache.changed.connect (() => {
                window_to_desktop_cache.clear ();
            });
        }

        public static GLib.Icon get_icon_for_window (Meta.Window window) {
            var transient_for = window.get_transient_for ();
            if (transient_for != null) {
                return get_icon_for_window (transient_for);
            }

            GLib.DesktopAppInfo? desktop_app = null;
            desktop_app = window_to_desktop_cache[window];
            if (desktop_app != null) {
                var icon = desktop_app.get_icon ();
                if (icon != null) {
                    return icon;
                }
            }

            var sandbox_id = window.get_sandboxed_app_id ();

            var wm_instance = window.get_wm_class_instance ();
            desktop_app = app_cache.lookup_startup_wmclass (wm_instance);
            if (desktop_app != null && check_app_prefix (desktop_app, sandbox_id)) {
                var icon = desktop_app.get_icon ();
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            var wm_class = window.get_wm_class ();
            desktop_app = app_cache.lookup_startup_wmclass (wm_class);
            if (desktop_app != null && check_app_prefix (desktop_app, sandbox_id)) {
                var icon = desktop_app.get_icon ();
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            desktop_app = lookup_desktop_wmclass (wm_instance);
            if (desktop_app != null && check_app_prefix (desktop_app, sandbox_id)) {
                var icon = desktop_app.get_icon ();
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            desktop_app = lookup_desktop_wmclass (wm_class);
            if (desktop_app != null && check_app_prefix (desktop_app, sandbox_id)) {
                var icon = desktop_app.get_icon ();
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            desktop_app = get_app_from_id (sandbox_id);
            if (desktop_app != null) {
                var icon = desktop_app.get_icon ();
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            var gapplication_id = window.get_gtk_application_id ();
            desktop_app = get_app_from_id (gapplication_id);
            if (desktop_app != null) {
                var icon = desktop_app.get_icon ();
                if (icon != null) {
                    window_to_desktop_cache[window] = desktop_app;
                    return icon;
                }
            }

            if (window.get_client_type () == Meta.WindowClientType.X11) {
#if HAS_MUTTER46
                unowned Meta.Group group = window.x11_get_group ();
#else
                unowned Meta.Group group = window.get_group ();
#endif
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
                var icon = desktop_app.get_icon ();
                        if (icon != null) {
                            window_to_desktop_cache[window] = desktop_app;
                            return icon;
                        }
                    }
                }
            }

            // Haven't been able to get an icon for the window at this point,
            // return a default icon
            return new ThemedIcon ("application-default-icon");
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

        /**
         * Multiplies an integer by a floating scaling factor, and then
         * returns the result rounded to the nearest integer
         */
        public static int scale_to_int (int value, float scale_factor) {
            return (int) (Math.round ((float)value * scale_factor));
        }

        /**
         * Get the number of toplevel windows on a workspace excluding those that are
         * on all workspaces.
         *
         * We need `exclude` here because on Meta.Workspace.window_removed
         * the windows gets removed from workspace's internal window list but not display's window list
         * which Meta.Workspace uses for Meta.Workspace.list_windows ().
         *
         * @param workspace The workspace on which to count the windows
         * @param exclude a window to not count
         *
         */
        public static uint get_n_windows (Meta.Workspace workspace, bool on_primary = false, Meta.Window? exclude = null) {
            var n = 0;
            foreach (unowned var window in workspace.list_windows ()) {
                if (window.on_all_workspaces || window == exclude) {
                    continue;
                }

                if (
                    get_window_is_normal (window)
                    && (!on_primary || (on_primary && window.is_on_primary_monitor ()))) {
                    n ++;
                }
            }

            return n;
        }

        /**
         * Creates an actor showing the current contents of the given WindowActor.
         *
         * @param actor      The actor from which to create a snapshot
         * @param inner_rect The inner (actually visible) rectangle of the window
         *
         * @return           A copy of the actor at that time or %NULL
         */
        public static Clutter.Actor? get_window_actor_snapshot (
            Meta.WindowActor actor,
            Mtk.Rectangle inner_rect
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

            var container = new Clutter.Actor () {
                content = content,
                offscreen_redirect = Clutter.OffscreenRedirect.ALWAYS,
                x = inner_rect.x,
                y = inner_rect.y,
                width = inner_rect.width,
                height = inner_rect.height
            };

            return container;
        }

        /**
         * Creates a new reactive ClutterActor at 36px with the resize pixbuf
         *
         * @return The resize button actor
         */
        public static Clutter.Actor create_resize_button (float monitor_scale) {
            return new Icon.from_resource (
                BUTTON_SIZE,
                monitor_scale,
                "/org/pantheon/desktop/gala/buttons/resize.svg"
            );
        }

        private static HashTable<Meta.Window, X.Rectangle?> regions = new HashTable<Meta.Window, X.Rectangle?> (null, null);

        public static void x11_set_window_pass_through (Meta.Window window) {
            unowned var x11_display = window.display.get_x11_display ();

#if HAS_MUTTER46
            var x_window = x11_display.lookup_xwindow (window);
#else
            var x_window = window.get_xwindow ();
#endif
            unowned var xdisplay = x11_display.get_xdisplay ();

            int count, ordering;
            regions[window] = X.Shape.get_rectangles (xdisplay, x_window, 2, out count, out ordering)[0];

            X.Xrectangle rect = {};
            var region = X.Fixes.create_region (xdisplay, {rect});

            X.Fixes.set_window_shape_region (xdisplay, x_window, 2, 0, 0, region);

            X.Fixes.destroy_region (xdisplay, region);
        }

        public static void x11_unset_window_pass_through (Meta.Window window, bool restore_previous_region) {
            unowned var x11_display = window.display.get_x11_display ();

#if HAS_MUTTER46
            var x_window = x11_display.lookup_xwindow (window);
#else
            var x_window = window.get_xwindow ();
#endif
            unowned var xdisplay = x11_display.get_xdisplay ();

            if (restore_previous_region) {
                var region = regions[window];
                if (region == null) {
                    debug ("Cannot unset pass through: window not found.");
                    return;
                }

                X.Shape.combine_rectangles (xdisplay, x_window, 2, 0, 0, { region }, 0, 3);
            } else {
                X.Fixes.set_window_shape_region (xdisplay, x_window, 2, 0, 0, (X.XserverRegion) 0);
            }

            regions.remove (window);
        }

        /**
         * Utility that returns the given duration or 0 if animations are disabled.
         */
        public static uint get_animation_duration (uint duration) {
            return Meta.Prefs.get_gnome_animations () ? duration : 0;
        }

        public static inline bool get_window_is_normal (Meta.Window window) {
            switch (window.window_type) {
                case Meta.WindowType.NORMAL:
                case Meta.WindowType.DIALOG:
                case Meta.WindowType.MODAL_DIALOG:
                    return true;
                default:
                    return false;
            }
        }

        public static inline bool get_window_and_ancestors_normal (Meta.Window window) {
            var normal = true;
            window.foreach_ancestor ((ancestor_window) => {
                normal = normal || get_window_is_normal (ancestor_window);

                return normal;
            });

            return normal;
        }

        public static int calculate_button_size (float monitor_scale) {
            return Utils.scale_to_int (BUTTON_SIZE, monitor_scale);
        }

        private static bool? framebuffer_is_logical = null;
        public static bool get_framebuffer_is_logical () {
            if (framebuffer_is_logical != null) {
                return framebuffer_is_logical;
            }

            framebuffer_is_logical = false;

            var experimental_features = new Settings ("org.gnome.mutter").get_strv ("experimental-features");
            for (var i = 0; i < experimental_features.length; i++) {
                if (experimental_features[i] == "scale-monitor-framebuffer") {
                    framebuffer_is_logical = true;
                    break;
                }
            }

            return framebuffer_is_logical;
        }

        public static float get_ui_scaling_factor (Meta.Display display, int monitor_index) {
            if (get_framebuffer_is_logical ()) {
                return 1.0f;
            } else {
                return display.get_monitor_scale (monitor_index);
            }
        }
    }
}
