//
//  Copyright (C) 2012-2014 Tom Beckmann, Rico Tzschichholz
//                2025-2026 elementary, Inc.
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
    public class WindowManagerGala : Meta.Plugin, WindowManager {
        private class SizeChangeInfo {
            public Meta.SizeChange change;
            public Mtk.Rectangle old_rect;
            public Clutter.Actor snapshot;

            public SizeChangeInfo (Meta.SizeChange change, Mtk.Rectangle old_rect, Clutter.Actor snapshot) {
                this.change = change;
                this.old_rect = old_rect;
                this.snapshot = snapshot;
            }
        }

        private const string OPEN_MULTITASKING_VIEW = "dbus-send --session --dest=org.pantheon.gala --print-reply /org/pantheon/gala org.pantheon.gala.PerformAction int32:1";
        private const string OPEN_APPLICATIONS_MENU = "io.elementary.wingpanel --toggle-indicator=app-launcher";

        /**
         * {@inheritDoc}
         */
        public Clutter.Actor ui_group { get; protected set; }

        /**
         * {@inheritDoc}
         */
        public Clutter.Stage stage { get; protected set; }

        /**
         * {@inheritDoc}
         */
        public Clutter.Actor window_group { get; protected set; }

        /**
         * {@inheritDoc}
         */
        public Clutter.Actor top_window_group { get; protected set; }

        /**
         * {@inheritDoc}
         */
        public Meta.BackgroundGroup background_group { get; protected set; }

        private LayoutManager layout_manager;

        public ScreenSaverManager? screensaver { get; private set; }

        private HotCornerManager? hot_corner_manager = null;

        private KeyboardManager keyboard_manager;

        private InputMethod input_method;

        public WindowTracker? window_tracker { get; private set; }

        private WindowMover window_mover;

        private FilterManager filter_manager;

        private NotificationsManager notifications_manager;

        private ScreenshotManager screenshot_manager;

        /**
         * Allow to zoom in/out the entire desktop.
         */
        private Zoom? zoom = null;

        private Clutter.Actor? tile_preview;

        private DaemonManager daemon_manager;

        private WindowMenuManager window_menu_manager;

        private NotificationStack notification_stack;

        private LockScreenManager lock_screen_manager;

        private Gee.LinkedList<ModalProxy> modal_stack = new Gee.LinkedList<ModalProxy> ();

        private Gee.HashSet<Meta.WindowActor> minimizing = new Gee.HashSet<Meta.WindowActor> ();
        private Gee.HashSet<Meta.WindowActor> mapping = new Gee.HashSet<Meta.WindowActor> ();
        private Gee.HashSet<Meta.WindowActor> destroying = new Gee.HashSet<Meta.WindowActor> ();
        private Gee.HashSet<Meta.WindowActor> unminimizing = new Gee.HashSet<Meta.WindowActor> ();
        private Gee.HashMap<Meta.WindowActor, SizeChangeInfo> pending_size_change = new Gee.HashMap<Meta.WindowActor, SizeChangeInfo> ();
        private Gee.HashSet<Meta.WindowActor> changing_size = new Gee.HashSet<Meta.WindowActor> ();

        private GLib.Settings behavior_settings;

        private Gee.Map<Meta.Window, WindowGroup> overridden_window_group = new Gee.HashMap<Meta.Window, WindowGroup> ();

        construct {
            behavior_settings = new GLib.Settings ("io.elementary.desktop.wm.behavior");

            //Make it start watching the settings daemon bus
            Drawing.StyleManager.get_instance ();
        }

        public override void start () {
            input_method = new InputMethod (get_display ());
            Clutter.get_default_backend ().set_input_method (input_method);

            ShellClientsManager.init (this, input_method);
            BlurManager.init (this);
            daemon_manager = new DaemonManager (get_display ());
            window_menu_manager = new WindowMenuManager (this, daemon_manager);

            show_stage ();

            init_a11y ();

            AccessDialog.watch_portal ();


            filter_manager = new FilterManager (this);
            notifications_manager = new NotificationsManager ();
            screenshot_manager = new ScreenshotManager (this, notifications_manager, filter_manager);
            DBus.init (this, notifications_manager, screenshot_manager, layout_manager.window_overview);

            unowned Meta.Display display = get_display ();
            display.gl_video_memory_purged.connect (() => {
                Meta.Background.refresh_all ();
            });

            display.notify["focus-window"].connect (on_focus_window_changed);

#if WITH_SYSTEMD
            if (Meta.Util.is_wayland_compositor ()) {
                display.init_xserver.connect ((task) => {
                    start_x11_services.begin (task);
                    return true;
                });
            }
#endif
        }

#if WITH_SYSTEMD
        private async void start_x11_services (GLib.Task task) {
            try {
                var session_bus = yield GLib.Bus.@get (GLib.BusType.SESSION);
                yield session_bus.call (
                    "org.freedesktop.systemd1",
                    "/org/freedesktop/systemd1",
                    "org.freedesktop.systemd1.Manager",
                    "StartUnit",
                    new GLib.Variant ("(ss)", "gnome-session-x11-services-ready.target", "fail"),
                    new GLib.VariantType ("(o)"),
                    GLib.DBusCallFlags.NONE,
                    -1
                );
            } catch (Error e) {
                critical (e.message);
            } finally {
                task.return_boolean (true);
            }
        }
#endif

        private void show_stage () {
            unowned Meta.Display display = get_display ();

            WindowListener.init (display);
            keyboard_manager = new KeyboardManager (display);
            window_tracker = new WindowTracker ();
            WindowStateSaver.init (window_tracker);
            window_tracker.init (display);
            WindowAttentionTracker.init (display);
            window_mover = new WindowMover (display, WindowListener.get_default ());

            notification_stack = new NotificationStack (display);

            unowned var laters = display.get_compositor ().get_laters ();
            laters.add (Meta.LaterType.BEFORE_REDRAW, () => {
                WorkspaceManager.init (this);
                return false;
            });

            /* First create the layout manager. That will set up the initial structure
               with the stage and UI group that we need for the properties on the WM */
            layout_manager = new LayoutManager (display, daemon_manager);

            stage = layout_manager.stage;
            ui_group = layout_manager.ui_group;
            window_group = layout_manager.window_group;
            top_window_group = layout_manager.top_window_group;
            background_group = layout_manager.background_group;

            // Initialize plugins. The layout manager will get overridden components from the
            // plugin manager
            unowned var plugin_manager = PluginManager.get_default ();
            plugin_manager.initialize (this);

            /* Then once we have the layout structures that we expose to widgets
               and initialized the plugins, init the rest of the UI */
            layout_manager.init_ui (this);

            lock_screen_manager = new LockScreenManager (layout_manager.lock_screen);

            screensaver = new ScreenSaverManager (layout_manager.session_locker);

            /*keybindings*/
            var keybinding_settings = new GLib.Settings ("io.elementary.desktop.wm.keybindings");

            display.add_keybinding ("switch-to-workspace-first", keybinding_settings, IGNORE_AUTOREPEAT, handle_switch_to_workspace_end);
            display.add_keybinding ("switch-to-workspace-last", keybinding_settings, IGNORE_AUTOREPEAT, handle_switch_to_workspace_end);
            display.add_keybinding ("move-to-workspace-first", keybinding_settings, IGNORE_AUTOREPEAT, handle_move_to_workspace_end);
            display.add_keybinding ("move-to-workspace-last", keybinding_settings, IGNORE_AUTOREPEAT, handle_move_to_workspace_end);
            display.add_keybinding ("cycle-workspaces-next", keybinding_settings, NONE, handle_cycle_workspaces);
            display.add_keybinding ("cycle-workspaces-previous", keybinding_settings, NONE, handle_cycle_workspaces);
            display.add_keybinding ("panel-main-menu", keybinding_settings, IGNORE_AUTOREPEAT, handle_applications_menu);

            display.add_keybinding ("toggle-multitasking-view", keybinding_settings, IGNORE_AUTOREPEAT, layout_manager.multitasking_view.toggle);

            display.add_keybinding ("expose-all-windows", keybinding_settings, IGNORE_AUTOREPEAT, layout_manager.window_overview.toggle);

            display.overlay_key.connect (() => {
                // Showing panels in fullscreen is broken in X11
                if (InternalUtils.get_x11_in_fullscreen (display) &&
                    behavior_settings.get_string ("overlay-action") == OPEN_APPLICATIONS_MENU
                ) {
                    return;
                }

                launch_action (ActionKeys.OVERLAY_ACTION);
            });

            Meta.KeyBinding.set_custom_handler ("toggle-recording", () => {
                launch_action (ActionKeys.TOGGLE_RECORDING_ACTION);
            });

            Meta.KeyBinding.set_custom_handler ("switch-to-workspace-up", () => {});
            Meta.KeyBinding.set_custom_handler ("switch-to-workspace-down", () => {});
            Meta.KeyBinding.set_custom_handler ("switch-to-workspace-left", handle_switch_to_workspace);
            Meta.KeyBinding.set_custom_handler ("switch-to-workspace-right", handle_switch_to_workspace);

            Meta.KeyBinding.set_custom_handler ("move-to-workspace-up", () => {});
            Meta.KeyBinding.set_custom_handler ("move-to-workspace-down", () => {});
            Meta.KeyBinding.set_custom_handler ("move-to-workspace-left", handle_move_to_workspace);
            Meta.KeyBinding.set_custom_handler ("move-to-workspace-right", handle_move_to_workspace);

            for (int i = 1; i < 13; i++) {
                Meta.KeyBinding.set_custom_handler ("switch-to-workspace-%d".printf (i), handle_switch_to_workspace);
                Meta.KeyBinding.set_custom_handler ("move-to-workspace-%d".printf (i), handle_move_to_workspace);
            }

            hot_corner_manager = new HotCornerManager (this, behavior_settings);

            zoom = new Zoom (this);

            var scroll_action = new SuperScrollAction (display);
            scroll_action.triggered.connect (handle_super_scroll);
            stage.add_action_full ("wm-super-scroll-action", CAPTURE, scroll_action);

            display.window_created.connect ((window) =>
                InternalUtils.wait_for_window_actor_visible (window, check_window_group)
            );

            stage.show ();

            plugin_manager.load_waiting_plugins ();

            Idle.add (() => {
                // let the session manager move to the next phase
#if WITH_SYSTEMD
                Systemd.Daemon.notify (true, "READY=1");
#endif
                display.get_context ().notify_ready ();
                return GLib.Source.REMOVE;
            });
        }

        private void init_a11y () {
            if (!Clutter.get_accessibility_enabled ()) {
                warning ("Clutter has no accessibility enabled");
                return;
            }

            string[] args = {};
            unowned string[] _args = args;
            AtkBridge.adaptor_init (ref _args);
        }

        public void launch_action (string action_key) {
            try {
                var action = behavior_settings.get_string (action_key);
                if (action != null) {
                    Process.spawn_command_line_async (action);
                }
            } catch (Error e) {
                warning (e.message);
            }
        }


        private bool handle_super_scroll (uint32 timestamp, double dx, double dy) {
            if (behavior_settings.get_enum ("super-scroll-action") != 1) {
                return Clutter.EVENT_PROPAGATE;
            }

            var d = dx.abs () > dy.abs () ? dx : dy;

            if (d > 0) {
                switch_to_next_workspace (Meta.MotionDirection.RIGHT, timestamp);
            } else if (d < 0) {
                switch_to_next_workspace (Meta.MotionDirection.LEFT, timestamp);
            }

            return Clutter.EVENT_STOP;
        }

        private void handle_cycle_workspaces (Meta.Display display, Meta.Window? window, Clutter.KeyEvent? event,
            Meta.KeyBinding binding) {
            var direction = (binding.get_name () == "cycle-workspaces-next" ? 1 : -1);
            unowned var manager = display.get_workspace_manager ();
            var active_workspace_index = manager.get_active_workspace_index ();
            var index = active_workspace_index + direction;

            if (index < 0) {
                index = manager.get_n_workspaces () - 2;
            } else if (index > manager.get_n_workspaces () - 2) {
                index = 0;
            }

            if (active_workspace_index != index) {
                var timestamp = event != null ? event.get_time () : Meta.CURRENT_TIME;
                manager.get_workspace_by_index (index).activate (timestamp);
            } else {
                InternalUtils.bell_notify (display);
            }
        }

        private void handle_move_to_workspace (Meta.Display display, Meta.Window? window,
            Clutter.KeyEvent? event, Meta.KeyBinding binding) {
            if (window == null) {
                return;
            }

            unowned var name = binding.get_name () ;
            unowned var workspace_manager = display.get_workspace_manager ();
            unowned var active_workspace = workspace_manager.get_active_workspace ();
            unowned Meta.Workspace? target_workspace = null;

            if (name == "move-to-workspace-left" || name == "move-to-workspace-right") {
                var direction = (name == "move-to-workspace-left" ? Meta.MotionDirection.LEFT : Meta.MotionDirection.RIGHT);
                target_workspace = active_workspace.get_neighbor (direction);
            } else {
                var workspace_number = int.parse (name.offset ("move-to-workspace-".length)) - 1;
                var workspace_index = workspace_number.clamp (0, workspace_manager.n_workspaces - 1);

                target_workspace = workspace_manager.get_workspace_by_index (workspace_index);
            }

            if (target_workspace != null) {
                var timestamp = event != null ? event.get_time () : Meta.CURRENT_TIME;
                move_window (window, target_workspace, timestamp);
            }
        }

        private void handle_move_to_workspace_end (Meta.Display display, Meta.Window? window,
            Clutter.KeyEvent? event, Meta.KeyBinding binding) {
            if (window == null) {
                return;
            }

            var timestamp = event != null ? event.get_time (): Meta.CURRENT_TIME;
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var index = (binding.get_name () == "move-to-workspace-first" ? 0 : manager.get_n_workspaces () - 1);
            unowned var workspace = manager.get_workspace_by_index (index);
            window.change_workspace (workspace);
            workspace.activate_with_focus (window, timestamp);
        }

        private void handle_switch_to_workspace (Meta.Display display, Meta.Window? window,
            Clutter.KeyEvent? event, Meta.KeyBinding binding) {
            var timestamp = event != null ? event.get_time () : Meta.CURRENT_TIME;
            unowned var name = binding.get_name ();

            if (name == "switch-to-workspace-left" || name == "switch-to-workspace-right") {
                var direction = (name == "switch-to-workspace-left" ? Meta.MotionDirection.LEFT : Meta.MotionDirection.RIGHT);
                switch_to_next_workspace (direction, timestamp);
            } else {
                unowned var workspace_manager = get_display ().get_workspace_manager ();

                var workspace_number = int.parse (name.offset ("switch-to-workspace-".length)) - 1;
                var workspace_index = workspace_number.clamp (0, workspace_manager.n_workspaces - 1);

                var workspace = workspace_manager.get_workspace_by_index (workspace_index);
                if (workspace == null) {
                    return;
                }

                workspace.activate (timestamp);
            }
        }

        private void handle_switch_to_workspace_end (Meta.Display display, Meta.Window? window,
            Clutter.KeyEvent? event, Meta.KeyBinding binding) {
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
            var index = (binding.get_name () == "switch-to-workspace-first" ? 0 : manager.n_workspaces - 1);
            manager.get_workspace_by_index (index).activate (event != null ? event.get_time () : Meta.CURRENT_TIME);
        }

        private void handle_applications_menu (Meta.Display display, Meta.Window? window,
            Clutter.KeyEvent? event, Meta.KeyBinding binding) {
            launch_action (ActionKeys.PANEL_MAIN_MENU_ACTION);
        }

        /**
         * {@inheritDoc}
         */
        public void switch_to_next_workspace (Meta.MotionDirection direction, uint32 timestamp) {
            layout_manager.multitasking_view.switch_to_next_workspace (direction);
        }

        /**
         * {@inheritDoc}
         */
        public void move_window (Meta.Window? window, Meta.Workspace workspace, uint32 timestamp) {
            if (window == null) {
                return;
            }

            unowned Meta.Display display = get_display ();
            unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();

            unowned var active = manager.get_active_workspace ();

            // don't allow empty workspaces to be created by moving, if we have dynamic workspaces
            if (Utils.get_n_windows (active) == 1 && workspace.index () == manager.n_workspaces - 1) {
                InternalUtils.bell_notify (display);
                return;
            }

            // don't allow moving into non-existing workspaces
            if (active == workspace) {
                InternalUtils.bell_notify (display);
                return;
            }

            layout_manager.multitasking_view.move_window (window, workspace);
        }

        /**
         * {@inheritDoc}
         */
        public ModalProxy push_modal (Clutter.Actor actor, bool grab) {
            var proxy = new ModalProxy ();

            modal_stack.offer_head (proxy);

            if (grab) {
                proxy.grab = stage.grab (actor);
            }

            on_focus_window_changed ();

            // modal already active
            if (modal_stack.size >= 2) {
                return proxy;
            }

#if HAS_MUTTER48
            get_display ().get_compositor ().disable_unredirect ();
#else
            get_display ().disable_unredirect ();
#endif
            return proxy;
        }

        /**
         * {@inheritDoc}
         */
        public void pop_modal (ModalProxy proxy) {
            if (!modal_stack.remove (proxy)) {
                warning ("Attempted to remove a modal proxy that was not in the stack");
                return;
            }

            if (proxy.grab != null) {
                proxy.grab.dismiss ();
            }

            on_focus_window_changed ();

            if (is_modal ()) {
                return;
            }

            unowned var display = get_display ();
#if HAS_MUTTER48
            display.get_compositor ().enable_unredirect ();
#else
            display.enable_unredirect ();
#endif
            display.focus_default_window (display.get_current_time ());
        }

        /**
         * {@inheritDoc}
         */
        public bool is_modal () {
            return !modal_stack.is_empty;
        }

        /**
         * {@inheritDoc}
         */
        public bool modal_proxy_valid (ModalProxy proxy) {
            return (proxy in modal_stack);
        }

        private void on_focus_window_changed () {
            unowned var display = get_display ();

            if (!is_modal () || modal_stack.peek_head ().grab != null || display.focus_window == null) {
                return;
            }

            if (overridden_window_group.has_key (display.focus_window)) {
                var overridden_group = overridden_window_group[display.focus_window];

                if (modal_stack.peek_head ().is_window_group_allowed (overridden_group)) {
                    return;
                }
            }

            display.unset_input_focus (display.get_current_time ());
        }

        private void dim_parent_window (Meta.Window window) {
            if (window.window_type != MODAL_DIALOG) {
                return;
            }

            unowned var transient = window.get_transient_for ();
            if (transient == null || transient == window) {
                warning ("No transient found");
                return;
            }

            unowned var transient_actor = (Meta.WindowActor) transient.get_compositor_private ();
            var dark_effect = new Clutter.BrightnessContrastEffect ();
            dark_effect.set_brightness (-0.4f);
            transient_actor.add_effect_with_name ("dim-parent", dark_effect);

            window.unmanaged.connect (() => {
                if (transient_actor != null && transient_actor.get_effect ("dim-parent") != null) {
                    transient_actor.remove_effect_by_name ("dim-parent");
                }
            });
        }

        /**
         * {@inheritDoc}
         */
        public void perform_action (ActionType type) {
            unowned var display = get_display ();
            unowned var current = display.get_focus_window ();

            switch (type) {
                case ActionType.SHOW_MULTITASKING_VIEW:
                    if (filter_action (MULTITASKING_VIEW)) {
                        break;
                    }

                    layout_manager.multitasking_view.toggle ();
                    break;
                case ActionType.MAXIMIZE_CURRENT:
                    if (current == null || current.window_type != Meta.WindowType.NORMAL || !current.can_maximize ())
                        break;

#if HAS_MUTTER49
                    if (current.is_maximized ()) {
                        current.unmaximize ();
                    } else {
                        current.maximize ();
                    }
#else
                    var maximize_flags = current.get_maximized ();
                    if (Meta.MaximizeFlags.VERTICAL in maximize_flags || Meta.MaximizeFlags.HORIZONTAL in maximize_flags)
                        current.unmaximize (Meta.MaximizeFlags.HORIZONTAL | Meta.MaximizeFlags.VERTICAL);
                    else
                        current.maximize (Meta.MaximizeFlags.HORIZONTAL | Meta.MaximizeFlags.VERTICAL);
#endif
                    break;
                case ActionType.HIDE_CURRENT:
                    if (current != null && current.window_type == Meta.WindowType.NORMAL)
                        current.minimize ();
                    break;
                case ActionType.START_MOVE_CURRENT:
                    warning ("Action START_MOVE_CURRENT is deprecated");
                    break;
                case ActionType.START_RESIZE_CURRENT:
                    warning ("Action START_RESIZE_CURRENT is deprecated");
                    break;
                case ActionType.TOGGLE_ALWAYS_ON_TOP_CURRENT:
                    if (current == null)
                        break;

                    if (current.is_above ())
                        current.unmake_above ();
                    else
                        current.make_above ();
                    break;
                case ActionType.TOGGLE_ALWAYS_ON_VISIBLE_WORKSPACE_CURRENT:
                    if (current == null)
                        break;

                    if (current.on_all_workspaces)
                        current.unstick ();
                    else
                        current.stick ();
                    break;
                case ActionType.SWITCH_TO_WORKSPACE_PREVIOUS:
                    if (filter_action (SWITCH_WORKSPACE)) {
                        break;
                    }

                    switch_to_next_workspace (Meta.MotionDirection.LEFT, Meta.CURRENT_TIME);
                    break;
                case ActionType.SWITCH_TO_WORKSPACE_NEXT:
                    if (filter_action (SWITCH_WORKSPACE)) {
                        break;
                    }

                    switch_to_next_workspace (Meta.MotionDirection.RIGHT, Meta.CURRENT_TIME);
                    break;
                case ActionType.MOVE_CURRENT_WORKSPACE_LEFT:
                    unowned var workspace_manager = get_display ().get_workspace_manager ();
                    unowned var active_workspace = workspace_manager.get_active_workspace ();
                    unowned var target_workspace = active_workspace.get_neighbor (Meta.MotionDirection.LEFT);
                    move_window (current, target_workspace, Meta.CURRENT_TIME);
                    break;
                case ActionType.MOVE_CURRENT_WORKSPACE_RIGHT:
                    unowned var workspace_manager = get_display ().get_workspace_manager ();
                    unowned var active_workspace = workspace_manager.get_active_workspace ();
                    unowned var target_workspace = active_workspace.get_neighbor (Meta.MotionDirection.RIGHT);
                    move_window (current, target_workspace, Meta.CURRENT_TIME);
                    break;
                case ActionType.CLOSE_CURRENT:
                    if (current != null && current.can_close ())
                        current.@delete (Meta.CURRENT_TIME);
                    break;
                case ActionType.OPEN_LAUNCHER:
                    launch_action (ActionKeys.PANEL_MAIN_MENU_ACTION);
                    break;
                case ActionType.WINDOW_OVERVIEW:
                    if (filter_action (WINDOW_OVERVIEW)) {
                        break;
                    }

                    layout_manager.window_overview.toggle ();
                    critical ("Window overview is deprecated");
                    break;
                case ActionType.WINDOW_OVERVIEW_ALL:
                    if (filter_action (WINDOW_OVERVIEW)) {
                        break;
                    }

                    layout_manager.window_overview.toggle ();
                    break;
                case ActionType.SWITCH_TO_WORKSPACE_LAST:
                    if (filter_action (SWITCH_WORKSPACE)) {
                        break;
                    }

                    unowned var manager = display.get_workspace_manager ();
                    unowned var workspace = manager.get_workspace_by_index (manager.get_n_workspaces () - 1);
                    workspace.activate (display.get_current_time ());
                    break;
                case ActionType.SCREENSHOT_CURRENT:
                    if (filter_action (SCREENSHOT_WINDOW)) {
                        break;
                    }

                    screenshot_manager.handle_screenshot_current_window_shortcut.begin (false);
                    break;
                default:
                    warning ("Trying to run unknown action");
                    break;
            }
        }

        public override void show_window_menu (Meta.Window window, Meta.WindowMenuType menu, int x, int y) {
            if (menu != WM) {
                warning ("Unsupported window menu type");
                return;
            }

            if (!Utils.get_window_is_normal (window) || NotificationStack.is_notification (window)) {
                return;
            }

            window_menu_manager.show_window_menu (window, x, y);
        }

        public override void show_tile_preview (Meta.Window window, Mtk.Rectangle tile_rect, int tile_monitor_number) {
            if (tile_preview == null) {
                tile_preview = new Clutter.Actor () {
                    background_color = Drawing.StyleManager.get_instance ().theme_accent_color,
                    opacity = 0
                };

                window_group.add_child (tile_preview);
            } else {
                float width, height, x, y;
                tile_preview.get_position (out x, out y);
                tile_preview.get_size (out width, out height);

                if ((tile_rect.width == width && tile_rect.height == height && tile_rect.x == x && tile_rect.y == y)
                    || tile_preview.get_transition ("size") != null) {
                    return;
                }
            }

            unowned Meta.WindowActor window_actor = window.get_compositor_private () as Meta.WindowActor;
            window_group.set_child_below_sibling (tile_preview, window_actor);

            var duration = Utils.get_animation_duration (AnimationDuration.SNAP / 2U);

            var rect = window.get_frame_rect ();
            tile_preview.set_position (rect.x, rect.y);
            tile_preview.set_size (rect.width, rect.height);
            tile_preview.show ();

            tile_preview.save_easing_state ();
            tile_preview.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
            tile_preview.set_easing_duration (duration);
            tile_preview.opacity = 255U;
            tile_preview.set_position (tile_rect.x, tile_rect.y);
            tile_preview.set_size (tile_rect.width, tile_rect.height);
            tile_preview.restore_easing_state ();
        }

        public override void hide_tile_preview () {
            if (tile_preview != null) {
                tile_preview.remove_all_transitions ();
                tile_preview.opacity = 0U;
                tile_preview.hide ();
                tile_preview = null;
            }
        }

        public override void show_window_menu_for_rect (Meta.Window window, Meta.WindowMenuType menu, Mtk.Rectangle rect) {
            show_window_menu (window, menu, rect.x, rect.y);
        }

        /**
         * Tells the wm to place the {@link window} in the given {@link new_group} instead of the default
         * window group as determined by the wm.
         * The wm will also automatically place transient windows of {@link window} in the same group.
         */
        public void override_window_group (Meta.Window window, WindowGroup new_group) {
            overridden_window_group[window] = new_group;
            window.unmanaged.connect ((_window) => overridden_window_group.unset (_window));

            InternalUtils.wait_for_window_actor_visible (window, (actor) => {
                layout_manager.change_window_group (actor, new_group);

                // FIXME: workaround for https://github.com/elementary/dock/issues/537
                actor.set_scale (1.0, 1.0);
                actor.opacity = 255;
            });
        }

        private void check_window_group (Meta.WindowActor actor) {
            unowned var window = actor.get_meta_window ();

            if (overridden_window_group.has_key (window)) {
                /* We are already overridden so make sure to ignore it */
                return;
            }

            /* Check if we're a transient of a window with an overridden group and if so place there */
            window.foreach_ancestor ((ancestor) => {
                if (overridden_window_group.has_key (ancestor)) {
                    override_window_group (window, overridden_window_group[ancestor]);
                    return false;
                }

                return true;
            });

            if (overridden_window_group.has_key (window)) {
                /* We found an ancestor with an overridden group so we are now being placed in the same group */
                return;
            }

            if (SessionSettings.is_greeter ()) {
                /* If we are in the greeter only the lock screen group is visible,
                   so put everything there. This makes sure stuff like initial setup, keyboard layout overview
                   etc. are still visible */
                override_window_group (window, LOCK_SCREEN);
                return;
            }

            if (NotificationStack.is_notification (window)) {
                override_window_group (window, DESKTOP_SHELL);
                notification_stack.show_notification (actor);
            }

            // Workaround for X11 bug: https://github.com/elementary/gala/issues/2071
            if (window.window_type == MENU ||
                window.window_type == DROPDOWN_MENU ||
                window.window_type == POPUP_MENU ||
                window.window_type == TOOLTIP
            ) {
                layout_manager.change_window_group (actor, MENU);
            }

            // Workaround for X11 bug: https://github.com/elementary/dock/issues/479
            if (!Meta.Util.is_wayland_compositor () && window.window_type == DND) {
                InternalUtils.clutter_actor_reparent (actor, get_display ().get_compositor ().get_feedback_group ());
            }
        }

        /*
         * effects
         */

        // must wait for size_changed to get updated frame_rect
        // as which_change is not passed to size_changed, save it as instance variable
        public override void size_change (Meta.WindowActor actor, Meta.SizeChange which_change, Mtk.Rectangle old_frame_rect, Mtk.Rectangle old_buffer_rect) {
            if (actor.meta_window.window_type != NORMAL || !Meta.Prefs.get_gnome_animations ()) {
                size_change_completed (actor);
                return;
            }

            var snapshot = Utils.get_window_actor_snapshot (actor, old_frame_rect);

            if (snapshot == null) {
                size_change_completed (actor);
                return;
            }

            var info = new SizeChangeInfo (which_change, old_frame_rect, snapshot);
            pending_size_change[actor] = info;
        }

        // size_changed gets called after frame_rect has updated
        public override void size_changed (Meta.WindowActor actor) {
            SizeChangeInfo info;
            if (!pending_size_change.unset (actor, out info)) {
                return;
            }

            unowned var window = actor.get_meta_window ();
            var new_rect = window.get_frame_rect ();

            var old_rect = info.old_rect;

            switch (info.change) {
                case Meta.SizeChange.MAXIMIZE:
                case Meta.SizeChange.FULLSCREEN:
                    // don't animate resizing of two tiled windows with mouse drag
                    if (window.get_tile_match () != null && !window.maximized_horizontally) {
                        var old_end = old_rect.x + old_rect.width;
                        var new_end = new_rect.x + new_rect.width;

                        // a tiled window is just resized (and not moved) if its start_x or its end_x stays the same
                        if (old_rect.x == new_rect.x || old_end == new_end) {
                            break;
                        }
                    }

                    animate_size_change.begin (actor, old_rect, new_rect, info.snapshot);
                    break;
                case Meta.SizeChange.UNMAXIMIZE:
                case Meta.SizeChange.UNFULLSCREEN:
                    animate_size_change.begin (actor, old_rect, new_rect, info.snapshot);
                    break;
                default:
                    break;
            }

            size_change_completed (actor);
        }

        private async void animate_size_change (Meta.WindowActor actor, Mtk.Rectangle old_rect, Mtk.Rectangle new_rect, Clutter.Actor snapshot) {
            kill_window_effects (actor);

            changing_size.add (actor);

            snapshot.set_position (old_rect.x, old_rect.y);

            ui_group.add_child (snapshot);

            var snapshot_scale_x = (double) new_rect.width / old_rect.width;
            var snapshot_scale_y = (double) new_rect.height / old_rect.height;

            snapshot.save_easing_state ();
            snapshot.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
            snapshot.set_easing_duration (AnimationDuration.SNAP);
            snapshot.set_position (new_rect.x, new_rect.y);
            snapshot.set_scale (snapshot_scale_x, snapshot_scale_y);
            snapshot.opacity = 0U;
            snapshot.restore_easing_state ();

            var actor_scale_x = (double) old_rect.width / new_rect.width;
            var actor_scale_y = (double) old_rect.height / new_rect.height;

            /* Since we scale the actor, the difference between the actor origin and where the content actually
               starts (i.e. the difference between buffer rect and frame rect origins) is now scaled too.
               Therefore calculate the position where the content starts (i.e. where the frame rect would be)
               at this size. With the snapshot we don't have this problem because when we take it, we clip it
               to the frame rect so the actor origin is always the content origin there. */

            var new_buffer_rect = actor.meta_window.get_buffer_rect ();

            var scaled_frame_rect_x = new_buffer_rect.x + (new_rect.x - new_buffer_rect.x) * actor_scale_x;
            var scaled_frame_rect_y = new_buffer_rect.y + (new_rect.y - new_buffer_rect.y) * actor_scale_y;

            var translation_x = (float) (old_rect.x - scaled_frame_rect_x);
            var translation_y = (float) (old_rect.y - scaled_frame_rect_y);

            actor.set_pivot_point (0.0f, 0.0f);

            var actor_transition_builder = new TransitionBuilder (actor, AnimationDuration.SNAP, EASE_IN_OUT_QUAD);
            actor_transition_builder.add_property_with_from ("scale-x", actor_scale_x, 1.0);
            actor_transition_builder.add_property_with_from ("scale-y", actor_scale_y, 1.0);
            actor_transition_builder.add_property_with_from ("translation-x", translation_x, 0.0f);
            actor_transition_builder.add_property_with_from ("translation-y", translation_y, 0.0f);

            yield actor_transition_builder.run ();

            ui_group.remove_child (snapshot);
            changing_size.remove (actor);
        }

        public override void minimize (Meta.WindowActor actor) {
            animate_minimize.begin (actor);
        }

        private async void animate_minimize (Meta.WindowActor actor) {
            if (actor.get_meta_window ().window_type != NORMAL) {
                minimize_completed (actor);
                return;
            }

            kill_window_effects (actor);
            minimizing.add (actor);

            var builder = new TransitionBuilder (actor, AnimationDuration.HIDE, EASE_IN_EXPO);

            Mtk.Rectangle icon = {};
            if (actor.get_meta_window ().get_icon_geometry (out icon)) {
                // Fix icon position and size according to ui scaling factor.
                var ui_scale = get_display ().get_monitor_scale (get_display ().get_monitor_index_for_rect (icon));
                icon.x = Utils.scale_to_int (icon.x, ui_scale);
                icon.y = Utils.scale_to_int (icon.y, ui_scale);
                icon.width = Utils.scale_to_int (icon.width, ui_scale);
                icon.height = Utils.scale_to_int (icon.height, ui_scale);

                actor.set_pivot_point (
                    (actor.x - icon.x) / (icon.width - actor.width),
                    (actor.y - icon.y) / (icon.height - actor.height)
                );

                builder.add_property ("scale-x", (double) (icon.width / actor.width));
                builder.add_property ("scale-y", (double) (icon.height / actor.height));
            } else {
                actor.set_pivot_point (0.5f, 1.0f);

                builder.add_property ("scale-x", 0.0);
                builder.add_property ("scale-y", 0.0);
            }

            builder.add_property ("opacity", 0u);

            yield builder.run ();

            actor.set_pivot_point (0.0f, 0.0f);
            minimizing.remove (actor);
            minimize_completed (actor);
        }

        public override void unminimize (Meta.WindowActor actor) {
            animate_unminimize.begin (actor);
        }

        private async void animate_unminimize (Meta.WindowActor actor) {
            actor.show ();

            if (actor.meta_window.window_type != NORMAL) {
                unminimize_completed (actor);
                return;
            }

            actor.remove_all_transitions ();

            unminimizing.add (actor);

            actor.set_pivot_point (0.5f, 1.0f);

            var builder = new TransitionBuilder (actor, AnimationDuration.HIDE, EASE_OUT_EXPO);
            builder.add_property_with_from ("scale-x", 0.01, 1.0);
            builder.add_property_with_from ("scale-y", 0.1, 1.0);
            builder.add_property_with_from ("opacity", 0U, 255U);

            yield builder.run ();

            unminimizing.remove (actor);
            unminimize_completed (actor);
        }

        public override void map (Meta.WindowActor actor) {
            unowned var window = actor.get_meta_window ();

            WindowStateSaver.on_map (window);

            actor.remove_all_transitions ();
            actor.show ();

            // Notifications initial animation is handled by the notification stack
            if (NotificationStack.is_notification (window) || !Meta.Prefs.get_gnome_animations ()) {
                dim_parent_window (window);
                map_completed (actor);
                return;
            }

            animate_map.begin (actor);
        }

        private async void animate_map (Meta.WindowActor actor) {
            var window = actor.meta_window;

            mapping.add (actor);

            switch (window.window_type) {
                case Meta.WindowType.NORMAL:
                    if (window.maximized_vertically || window.maximized_horizontally) {
                        var outer_rect = window.get_frame_rect ();
                        actor.set_position (outer_rect.x, outer_rect.y);
                    }

                    actor.set_pivot_point (0.5f, 1.0f);

                    var builder = new TransitionBuilder (actor, AnimationDuration.HIDE, EASE_OUT_EXPO);
                    builder.add_property_with_from ("scale-x", 0.01, 1.0);
                    builder.add_property_with_from ("scale-y", 0.1, 1.0);
                    builder.add_property_with_from ("opacity", 0U, 255U);
                    yield builder.run ();
                    break;

                case Meta.WindowType.MODAL_DIALOG:
                case Meta.WindowType.DIALOG:
                    dim_parent_window (window);
                    actor.set_pivot_point (0.5f, 0.5f);

                    var builder = new TransitionBuilder (actor, 200, EASE_OUT_QUAD);
                    builder.add_property_with_from ("scale-x", 1.05, 1.0);
                    builder.add_property_with_from ("scale-y", 1.05, 1.0);
                    builder.add_property_with_from ("opacity", 0U, 255U);
                    yield builder.run ();
                    break;

                default:
                    break;
            }

            mapping.remove (actor);
            map_completed (actor);
        }

        public override void destroy (Meta.WindowActor actor) {
            actor.remove_all_transitions ();

            animate_destroy.begin (actor);
        }

        private async void animate_destroy (Meta.WindowActor actor) {
            var window = actor.meta_window;

            destroying.add (actor);

            switch (window.window_type) {
                case Meta.WindowType.NORMAL:
                    actor.set_pivot_point (0.5f, 0.5f);
                    actor.show ();

                    var builder = new TransitionBuilder (actor, AnimationDuration.CLOSE, LINEAR);
                    builder.add_property ("scale-x", 0.8);
                    builder.add_property ("scale-y", 0.8);
                    builder.add_property ("opacity", 0U);
                    yield builder.run ();

                    Utils.clear_window_cache (window);
                    break;

                case Meta.WindowType.MODAL_DIALOG:
                case Meta.WindowType.DIALOG:
                    actor.set_pivot_point (0.5f, 0.5f);

                    var builder = new TransitionBuilder (actor, 150, EASE_OUT_QUAD);
                    builder.add_property ("scale-x", 1.05);
                    builder.add_property ("scale-y", 1.05);
                    builder.add_property ("opacity", 0U);
                    yield builder.run ();
                    break;

                default:
                    if (NotificationStack.is_notification (window)) {
                        yield notification_stack.destroy_notification (actor);
                    }
                    break;
            }

            destroying.remove (actor);
            destroy_completed (actor);
        }

        /**
         * Cancel attached animation of an actor and reset its animation properties.
         */
        private void end_animation (ref Gee.HashSet<Meta.WindowActor> list, Meta.WindowActor actor) {
            if (!list.contains (actor)) {
                return;
            }

            actor.remove_all_transitions ();
            actor.opacity = 255U;
            actor.set_scale (1.0, 1.0);
            actor.rotation_angle_x = 0.0;
            actor.set_pivot_point (0.0f, 0.0f);

            list.remove (actor);
        }

        public override void kill_window_effects (Meta.WindowActor actor) {
            if (pending_size_change.unset (actor)) {
                size_change_completed (actor);
            }

            end_animation (ref unminimizing, actor);
            end_animation (ref minimizing, actor);
            end_animation (ref mapping, actor);
            end_animation (ref destroying, actor);
            end_animation (ref changing_size, actor);
        }

        public override void switch_workspace (int from, int to, Meta.MotionDirection direction) {
            switch_workspace_completed ();
        }

        public override void kill_switch_workspace () {
            layout_manager.multitasking_view.kill_switch_workspace ();
        }

        public override void locate_pointer () {
            layout_manager.pointer_locator.show_ripple ();
        }

        public override bool keybinding_filter (Meta.KeyBinding binding) {
            if (!is_modal ()) {
                return false;
            }

            var action = Meta.Prefs.get_keybinding_action (binding.get_name ());

            switch (action) {
                case Meta.KeyBindingAction.OVERLAY_KEY:
                    if (behavior_settings.get_string ("overlay-action") == OPEN_MULTITASKING_VIEW) {
                        return filter_action (MULTITASKING_VIEW);
                    }

                    return true;
                case Meta.KeyBindingAction.WORKSPACE_1:
                case Meta.KeyBindingAction.WORKSPACE_2:
                case Meta.KeyBindingAction.WORKSPACE_3:
                case Meta.KeyBindingAction.WORKSPACE_4:
                case Meta.KeyBindingAction.WORKSPACE_5:
                case Meta.KeyBindingAction.WORKSPACE_6:
                case Meta.KeyBindingAction.WORKSPACE_7:
                case Meta.KeyBindingAction.WORKSPACE_8:
                case Meta.KeyBindingAction.WORKSPACE_9:
                case Meta.KeyBindingAction.WORKSPACE_10:
                case Meta.KeyBindingAction.WORKSPACE_11:
                case Meta.KeyBindingAction.WORKSPACE_12:
                case Meta.KeyBindingAction.WORKSPACE_LEFT:
                case Meta.KeyBindingAction.WORKSPACE_RIGHT:
                    return filter_action (SWITCH_WORKSPACE);
                case Meta.KeyBindingAction.SWITCH_APPLICATIONS:
                case Meta.KeyBindingAction.SWITCH_APPLICATIONS_BACKWARD:
                case Meta.KeyBindingAction.SWITCH_WINDOWS:
                case Meta.KeyBindingAction.SWITCH_WINDOWS_BACKWARD:
                case Meta.KeyBindingAction.SWITCH_GROUP:
                case Meta.KeyBindingAction.SWITCH_GROUP_BACKWARD:
                    return filter_action (SWITCH_WINDOWS);
                case Meta.KeyBindingAction.LOCATE_POINTER_KEY:
                    return filter_action (LOCATE_POINTER);
                case Meta.KeyBindingAction.NONE:
                    return filter_action (MEDIA_KEYS);
                default:
                    break;
            }

            switch (binding.get_name ()) {
                case "cycle-workspaces-next":
                case "cycle-workspaces-previous":
                case "switch-to-workspace-first":
                case "switch-to-workspace-last":
                    return filter_action (SWITCH_WORKSPACE);
                case "zoom-in":
                case "zoom-out":
                    return filter_action (ZOOM);
                case "toggle-multitasking-view":
                    return filter_action (MULTITASKING_VIEW);
                case "expose-all-windows":
                    return filter_action (WINDOW_OVERVIEW);
                case "screenshot":
                case "screenshot-clip":
                case "interactive-screenshot":
                    return filter_action (SCREENSHOT);
                case "area-screenshot":
                case "area-screenshot-clip":
                    return filter_action (SCREENSHOT_AREA);
                case "window-screenshot":
                case "window-screenshot-clip":
                    return filter_action (SCREENSHOT_WINDOW);
                default:
                    break;
            }

            return false;
        }

        public bool filter_action (ModalActions action) {
            if (!is_modal ()) {
                return false;
            }

            return modal_stack.peek_head ().filter_action (action);
        }

        public override void confirm_display_change () {
            unowned var monitor_manager = get_display ().get_context ().get_backend ().get_monitor_manager ();
            var timeout = monitor_manager.get_display_configuration_timeout ();
            var summary = ngettext (
                "Changes will automatically revert after %i second.",
                "Changes will automatically revert after %i seconds.",
                timeout
            );
            uint dialog_timeout_id = 0;

            var dialog = new AccessDialog (
                _("Keep new display settings?"),
                summary.printf (timeout),
                "preferences-desktop-display"
            ) {
                accept_label = _("Keep Settings"),
                deny_label = _("Use Previous Settings")
            };

            dialog.show.connect (() => {
                dialog_timeout_id = Timeout.add_seconds (timeout, () => {
                    dialog_timeout_id = 0;
                    dialog.close ();

                    return Source.REMOVE;
                });
            });

            dialog.response.connect ((res) => {
                if (dialog_timeout_id != 0) {
                    Source.remove (dialog_timeout_id);
                    dialog_timeout_id = 0;
                }

                complete_display_change (res == 0);
            });

            dialog.show ();
        }

        public override Meta.CloseDialog? create_close_dialog (Meta.Window window) {
            return new CloseDialog (window_tracker.get_app_for_window (window), window);
        }

        public override Meta.InhibitShortcutsDialog create_inhibit_shortcuts_dialog (Meta.Window window) {
            return new InhibitShortcutsDialog (window_tracker.get_app_for_window (window), window);
        }
    }
}
