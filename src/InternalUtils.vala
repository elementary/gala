/*
 * Copyright 2012 Tom Beckmann
 * Copyright 2012 Rico Tzschichholz
 * Copyright 2023-2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Gala {
    public enum InputArea {
        NONE,
        FULLSCREEN,
        DEFAULT
    }

    public class InternalUtils {
        /**
         * set the area where clutter can receive events
         **/
        public static void set_input_area (Meta.Display display, InputArea area) {
            if (Meta.Util.is_wayland_compositor ()) {
                return;
            }

            X.Xrectangle[] rects = {};

            switch (area) {
                case InputArea.FULLSCREEN:
                    int width, height;
                    display.get_size (out width, out height);

                    X.Xrectangle rect = {0, 0, (ushort)width, (ushort)height};
                    rects = {rect};
                    break;

                case InputArea.DEFAULT:
                    // add plugin's requested areas
                    foreach (var rect in PluginManager.get_default ().get_regions ()) {
                        rects += rect;
                    }

                    break;

                case InputArea.NONE:
                default:
                    rects = {};
                    break;
            }

            unowned Meta.X11Display x11display = display.get_x11_display ();
#if HAS_MUTTER47
            x11display.set_stage_input_region (rects);
#else
            var xregion = X.Fixes.create_region (x11display.get_xdisplay (), rects);
            x11display.set_stage_input_region (xregion);
#endif
        }

        /**
         * Inserts a workspace at the given index. To ensure the workspace is not immediately
         * removed again when in dynamic workspaces, the window is first placed on it.
         *
         * @param index  The index at which to insert the workspace
         * @param new_window A window that should be moved to the new workspace
         */
        public static void insert_workspace_with_window (int index, Meta.Window new_window) {
            unowned WorkspaceManager workspace_manager = WorkspaceManager.get_default ();
            workspace_manager.freeze_remove ();

            new_window.change_workspace_by_index (index, false);

#if HAS_MUTTER48
            unowned List<Meta.WindowActor> actors = new_window.get_display ().get_compositor ().get_window_actors ();
#else
            unowned List<Meta.WindowActor> actors = new_window.get_display ().get_window_actors ();
#endif
            foreach (unowned Meta.WindowActor actor in actors) {
                if (actor.is_destroyed ())
                    continue;

                unowned Meta.Window window = actor.get_meta_window ();
                if (window == new_window)
                    continue;

                var current_index = window.get_workspace ().index ();
                if (current_index >= index
                    && !window.on_all_workspaces) {
                    window.change_workspace_by_index (current_index + 1, true);
                }
            }

            workspace_manager.thaw_remove ();
        }

        public static Clutter.ActorBox actor_box_from_rect (float x, float y, float width, float height) {
            var actor_box = Clutter.ActorBox ();
            actor_box.init_rect (x, y, width, height);
            Clutter.ActorBox.clamp_to_pixel (ref actor_box);

            return actor_box;
        }

        public delegate void WindowActorReadyCallback (Meta.WindowActor window_actor);

        public static void wait_for_window_actor (Meta.Window window, owned WindowActorReadyCallback callback) {
            unowned var window_actor = (Meta.WindowActor) window.get_compositor_private ();
            if (window_actor != null) {
                callback (window_actor);
                return;
            }

            Idle.add (() => {
                window_actor = (Meta.WindowActor) window.get_compositor_private ();

                if (window_actor != null) {
                    callback (window_actor);
                }

                return Source.REMOVE;
            });
        }

        public static void wait_for_window_actor_visible (Meta.Window window, owned WindowActorReadyCallback callback) {
            wait_for_window_actor (window, (window_actor) => {
                if (window_actor.visible) {
                    callback (window_actor);
                } else {
                    ulong show_handler = 0;
                    show_handler = window_actor.show.connect (() => {
                        window_actor.disconnect (show_handler);
                        callback (window_actor);
                    });
                }
            });
        }

        public static void clutter_actor_reparent (Clutter.Actor actor, Clutter.Actor new_parent) {
            if (actor == new_parent) {
                return;
            }

            actor.ref ();
            actor.get_parent ().remove_child (actor);
            new_parent.add_child (actor);
            actor.unref ();
        }

        public static void bell_notify (Meta.Display display) {
#if HAS_MUTTER48
            display.get_compositor ().get_stage ().context.get_backend ().get_default_seat ().bell_notify ();
#elif HAS_MUTTER47
            display.get_stage ().context.get_backend ().get_default_seat ().bell_notify ();
#else
            Clutter.get_default_backend ().get_default_seat ().bell_notify ();
#endif
        }

        public static bool get_x11_in_fullscreen (Meta.Display display) {
            var primary_monitor = display.get_primary_monitor ();
            var is_in_fullscreen = display.get_monitor_in_fullscreen (primary_monitor);
            return !Meta.Util.is_wayland_compositor () && is_in_fullscreen;
        }

        /**
         * Returns the most recently used "normal" window (as gotten via {@link get_window_is_normal}) in the given workspace.
         * If there is a not normal but more recent window (e.g. a menu/tooltip) any_window will be set to that window otherwise
         * it will be set to the same window that is returned.
         */
        public static Meta.Window? get_mru_window (Meta.Workspace workspace, out Meta.Window? any_window = null) {
            any_window = null;

            var list = workspace.list_windows ();

            if (list.is_empty ()) {
                return null;
            }

            list.sort ((a, b) => {
                return (int) b.get_user_time () - (int) a.get_user_time ();
            });

            foreach (var window in list) {
                if (!ShellClientsManager.get_instance ().is_positioned_window (window)) {
                    if (any_window == null) {
                        any_window = window;
                    }

                    if (!Utils.get_window_is_normal (window)) {
                        continue;
                    }

                    return window;
                }
            }

            return null;
        }
    }
}
