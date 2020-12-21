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

using Meta;
using Clutter;

namespace Gala {

    public enum WindowOverviewType {
        GRID = 0,
        NATURAL
    }

    public delegate void WindowPlacer (Actor window, Meta.Rectangle rect);

    public class WindowOverview : Actor, ActivatableComponent {
        const int BORDER = 10;
        const int TOP_GAP = 30;
        const int BOTTOM_GAP = 100;

        public WindowManager wm { get; construct; }

#if HAS_MUTTER330
        Meta.Display display;
#else
        Meta.Screen screen;
#endif

        ModalProxy modal_proxy;
        bool ready;

        // the workspaces which we expose right now
        List<Workspace> workspaces;

        public WindowOverview (WindowManager wm) {
            Object (wm : wm);
        }

        construct {
#if HAS_MUTTER330
            display = wm.get_display ();

            display.get_workspace_manager ().workspace_switched.connect (() => { close (); });
            display.restacked.connect (restack_windows);
#else
            screen = wm.get_screen ();

            screen.workspace_switched.connect (() => { close (); });
            screen.restacked.connect (restack_windows);
#endif

            visible = false;
            ready = true;
            reactive = true;
        }

        ~WindowOverview () {
#if HAS_MUTTER330
            display.restacked.disconnect (restack_windows);
#else
            screen.restacked.disconnect (restack_windows);
#endif
        }

        public override bool key_press_event (Clutter.KeyEvent event) {
            if (event.keyval == Clutter.Key.Escape) {
                close ();

                return true;
            }

            return false;
        }

        public override void key_focus_out () {
            if (!contains (get_stage ().key_focus))
                close ();
        }

        public override bool button_press_event (Clutter.ButtonEvent event) {
            if (event.button == 1)
                close ();

            return true;
        }

        /**
         * {@inheritDoc}
         */
        public bool is_opened () {
            return visible;
        }

        /**
         * {@inheritDoc}
         * You may specify 'all-windows' in hints to expose all windows
         */
        public void open (HashTable<string,Variant>? hints = null) {
            if (!ready)
                return;

            if (visible) {
                close ();
                return;
            }

            var all_windows = hints != null && "all-windows" in hints;

            var used_windows = new SList<Window> ();

            workspaces = new List<Workspace> ();

#if HAS_MUTTER330
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            if (all_windows) {
                for (int i = 0; i < manager.get_n_workspaces (); i++) {
                    workspaces.append (manager.get_workspace_by_index (i));
                }
            } else {
                workspaces.append (manager.get_active_workspace ());
            }
#else
            if (all_windows) {
                foreach (var workspace in screen.get_workspaces ())
                    workspaces.append (workspace);
            } else {
                workspaces.append (screen.get_active_workspace ());
            }
#endif

            foreach (var workspace in workspaces) {
                foreach (var window in workspace.list_windows ()) {
                    if (window.window_type != WindowType.NORMAL &&
                        window.window_type != WindowType.DOCK &&
                        window.window_type != WindowType.DIALOG ||
                        window.is_attached_dialog ()) {
                        var actor = window.get_compositor_private () as WindowActor;
                        if (actor != null)
                            actor.hide ();
                        continue;
                    }
                    if (window.window_type == WindowType.DOCK)
                        continue;

                    // skip windows that are on all workspace except we're currently
                    // processing the workspace it actually belongs to
                    if (window.is_on_all_workspaces () && window.get_workspace () != workspace)
                        continue;

                    used_windows.append (window);
                }
            }

            var n_windows = used_windows.length ();
            if (n_windows == 0)
                return;

            ready = false;

            foreach (var workspace in workspaces) {
                workspace.window_added.connect (add_window);
                workspace.window_removed.connect (remove_window);
            }

#if HAS_MUTTER330
            display.window_left_monitor.connect (window_left_monitor);

            // sort windows by stacking order
            var windows = display.sort_windows_by_stacking (used_windows);
#else
            screen.window_left_monitor.connect (window_left_monitor);

            // sort windows by stacking order
            var windows = screen.get_display ().sort_windows_by_stacking (used_windows);
#endif

            grab_key_focus ();

            modal_proxy = wm.push_modal ();
            modal_proxy.keybinding_filter = keybinding_filter;

            visible = true;

#if HAS_MUTTER330
            for (var i = 0; i < display.get_n_monitors (); i++) {
                var geometry = display.get_monitor_geometry (i);
#else
            for (var i = 0; i < screen.get_n_monitors (); i++) {
                var geometry = screen.get_monitor_geometry (i);
#endif

                var container = new WindowCloneContainer (null, true) {
                    padding_top = TOP_GAP,
                    padding_left = BORDER,
                    padding_right = BORDER,
                    padding_bottom = BOTTOM_GAP
                };
                container.set_position (geometry.x, geometry.y);
                container.set_size (geometry.width, geometry.height);
                container.window_selected.connect (thumb_selected);

                add_child (container);
            }

            foreach (var window in windows) {
                unowned WindowActor actor = window.get_compositor_private () as WindowActor;
                if (actor != null)
                    actor.hide ();

                unowned WindowCloneContainer container = get_child_at_index (window.get_monitor ()) as WindowCloneContainer;
                if (container == null)
                    continue;

                container.add_window (window);
            }

            foreach (var child in get_children ())
                ((WindowCloneContainer) child).open ();

            ready = true;
        }

        bool keybinding_filter (KeyBinding binding) {
            var name = binding.get_name ();
            return (name != "expose-windows" && name != "expose-all-windows");
        }

#if HAS_MUTTER330
        void restack_windows (Display display) {
            foreach (var child in get_children ())
                ((WindowCloneContainer) child).restack_windows (display);
        }
#else
        void restack_windows (Screen screen) {
            foreach (var child in get_children ())
                ((WindowCloneContainer) child).restack_windows (screen);
        }
#endif

        void window_left_monitor (int num, Window window) {
            unowned WindowCloneContainer container = get_child_at_index (num) as WindowCloneContainer;
            if (container == null)
                return;

            // make sure the window belongs to one of our workspaces
            foreach (var workspace in workspaces)
                if (window.located_on_workspace (workspace)) {
                    container.remove_window (window);
                    break;
                }
        }

        void add_window (Window window) {
            if (!visible
                || (window.window_type != WindowType.NORMAL && window.window_type != WindowType.DIALOG))
                return;

            unowned WindowCloneContainer container = get_child_at_index (window.get_monitor ()) as WindowCloneContainer;
            if (container == null)
                return;

            // make sure the window belongs to one of our workspaces
            foreach (var workspace in workspaces)
                if (window.located_on_workspace (workspace)) {
                    container.add_window (window);
                    break;
                }
        }

        void remove_window (Window window) {
            unowned WindowCloneContainer container = get_child_at_index (window.get_monitor ()) as WindowCloneContainer;
            if (container == null)
                return;

            container.remove_window (window);
        }

#if HAS_MUTTER330
        void thumb_selected (Window window) {
            if (window.get_workspace () == display.get_workspace_manager ().get_active_workspace ()) {
                window.activate (display.get_current_time ());
                close ();
            } else {
                close ();
                //wait for the animation to finish before switching
                Timeout.add (400, () => {
                    window.get_workspace ().activate_with_focus (window, display.get_current_time ());
                    return false;
                });
            }
        }
#else
        void thumb_selected (Window window) {
            if (window.get_workspace () == screen.get_active_workspace ()) {
                window.activate (screen.get_display ().get_current_time ());
                close ();
            } else {
                close ();
                //wait for the animation to finish before switching
                Timeout.add (400, () => {
                    window.get_workspace ().activate_with_focus (window, screen.get_display ().get_current_time ());
                    return false;
                });
            }
        }
#endif

        /**
         * {@inheritDoc}
         */
        public void close (HashTable<string,Variant>? hints = null) {
            if (!visible || !ready)
                return;

            foreach (var workspace in workspaces) {
                workspace.window_added.disconnect (add_window);
                workspace.window_removed.disconnect (remove_window);
            }
#if HAS_MUTTER330
            display.window_left_monitor.disconnect (window_left_monitor);
#else
            screen.window_left_monitor.disconnect (window_left_monitor);
#endif

            ready = false;

            wm.pop_modal (modal_proxy);

            foreach (var child in get_children ()) {
                ((WindowCloneContainer) child).close ();
            }

            Clutter.Threads.Timeout.add (300, () => {
                cleanup ();

                return false;
            });
        }

        void cleanup () {
            ready = true;
            visible = false;

#if HAS_MUTTER330
            foreach (var window in display.get_workspace_manager ().get_active_workspace ().list_windows ())
#else
            foreach (var window in screen.get_active_workspace ().list_windows ())
#endif
                if (window.showing_on_its_workspace ())
                    ((Actor) window.get_compositor_private ()).show ();

            destroy_all_children ();
        }
    }
}
