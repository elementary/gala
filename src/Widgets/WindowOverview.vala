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

    public enum WindowOverviewType {
        GRID = 0,
        NATURAL
    }

    public delegate void WindowPlacer (Clutter.Actor window, Meta.Rectangle rect);

    public class WindowOverview : Clutter.Actor, ActivatableComponent {
        private const int BORDER = 10;
        private const int TOP_GAP = 30;
        private const int BOTTOM_GAP = 100;

        public WindowManager wm { get; construct; }

        private Meta.Display display;
        private ModalProxy modal_proxy;
        private bool ready;

        // the workspaces which we expose right now
        private List<Meta.Workspace> workspaces;

        public WindowOverview (WindowManager wm) {
            Object (wm : wm);
        }

        construct {
            display = wm.get_display ();
            display.get_workspace_manager ().workspace_switched.connect (() => { close (); });
            display.restacked.connect (restack_windows);

            visible = false;
            ready = true;
            reactive = true;
        }

        ~WindowOverview () {
            display.restacked.disconnect (restack_windows);
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

            var used_windows = new SList<Meta.Window> ();

            workspaces = new List<Meta.Workspace> ();

            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            if (all_windows) {
                for (int i = 0; i < manager.get_n_workspaces (); i++) {
                    workspaces.append (manager.get_workspace_by_index (i));
                }
            } else {
                workspaces.append (manager.get_active_workspace ());
            }

            foreach (var workspace in workspaces) {
                foreach (var window in workspace.list_windows ()) {
                    if (window.window_type != Meta.WindowType.NORMAL &&
                        window.window_type != Meta.WindowType.DOCK &&
                        window.window_type != Meta.WindowType.DIALOG ||
                        window.is_attached_dialog ()) {
                        var actor = window.get_compositor_private () as Meta.WindowActor;
                        if (actor != null)
                            actor.hide ();
                        continue;
                    }
                    if (window.window_type == Meta.WindowType.DOCK)
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

            display.window_left_monitor.connect (window_left_monitor);

            // sort windows by stacking order
            var windows = display.sort_windows_by_stacking (used_windows);

            grab_key_focus ();

            modal_proxy = wm.push_modal (this);
            modal_proxy.set_keybinding_filter (keybinding_filter);

            visible = true;

            for (var i = 0; i < display.get_n_monitors (); i++) {
                var geometry = display.get_monitor_geometry (i);

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
                unowned Meta.WindowActor actor = window.get_compositor_private () as Meta.WindowActor;
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

        private bool keybinding_filter (Meta.KeyBinding binding) {
            var name = binding.get_name ();
            return (name != "expose-windows" && name != "expose-all-windows");
        }

        private void restack_windows (Meta.Display display) {
            foreach (var child in get_children ())
                ((WindowCloneContainer) child).restack_windows (display);
        }

        private void window_left_monitor (int num, Meta.Window window) {
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

        private void add_window (Meta.Window window) {
            if (!visible
                || (window.window_type != Meta.WindowType.NORMAL && window.window_type != Meta.WindowType.DIALOG))
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

        private void remove_window (Meta.Window window) {
            unowned WindowCloneContainer container = get_child_at_index (window.get_monitor ()) as WindowCloneContainer;
            if (container == null)
                return;

            container.remove_window (window);
        }

        private void thumb_selected (Meta.Window window) {
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

            display.window_left_monitor.disconnect (window_left_monitor);
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

        private void cleanup () {
            ready = true;
            visible = false;

            foreach (var window in display.get_workspace_manager ().get_active_workspace ().list_windows ())
                if (window.showing_on_its_workspace ())
                    ((Clutter.Actor) window.get_compositor_private ()).show ();

            destroy_all_children ();
        }
    }
}
