//
//  Copyright (C) 2012-2014 Tom Beckmann, Rico Tzschichholz
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
    public class WindowManagerGala : Meta.Plugin, WindowManager {
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
         * The group that contains all WindowActors that make shell elements, that is all windows reported as
         * ShellClientsManager.is_positioned_window.
         * It will (eventually) never be hidden by other components and is always on top of everything. Therefore elements are
         * responsible themselves for hiding depending on the state we are currently in (e.g. normal desktop, open multitasking view, fullscreen, etc.).
         */
        public Clutter.Actor shell_group { get; private set; }

        /**
         * {@inheritDoc}
         */
        public Meta.BackgroundGroup background_group { get; protected set; }

        /**
         * View that allows to see and manage all your windows and desktops.
         */
        public MultitaskingView multitasking_view { get; protected set; }

        public PointerLocator pointer_locator { get; private set; }

        private SystemBackground system_background;

#if !HAS_MUTTER48
        private Meta.PluginInfo info;
#endif

        private WindowSwitcher? window_switcher = null;

        public ActivatableComponent? window_overview { get; private set; }

        public ScreenSaverManager? screensaver { get; private set; }

        private HotCornerManager? hot_corner_manager = null;

        private KeyboardManager keyboard_manager;

        public WindowTracker? window_tracker { get; private set; }

        private FilterManager filter_manager;

        private NotificationsManager notifications_manager;

        private ScreenshotManager screenshot_manager;

        /**
         * Allow to zoom in/out the entire desktop.
         */
        private Zoom? zoom = null;

        private Clutter.Actor? tile_preview;

        private DaemonManager daemon_manager;

        private NotificationStack notification_stack;

        private Gee.LinkedList<ModalProxy> modal_stack = new Gee.LinkedList<ModalProxy> ();

        private Gee.HashSet<Meta.WindowActor> minimizing = new Gee.HashSet<Meta.WindowActor> ();
        private Gee.HashSet<Meta.WindowActor> maximizing = new Gee.HashSet<Meta.WindowActor> ();
        private Gee.HashSet<Meta.WindowActor> unmaximizing = new Gee.HashSet<Meta.WindowActor> ();
        private Gee.HashSet<Meta.WindowActor> mapping = new Gee.HashSet<Meta.WindowActor> ();
        private Gee.HashSet<Meta.WindowActor> destroying = new Gee.HashSet<Meta.WindowActor> ();
        private Gee.HashSet<Meta.WindowActor> unminimizing = new Gee.HashSet<Meta.WindowActor> ();
        private GLib.HashTable<Meta.Window, int> ws_assoc = new GLib.HashTable<Meta.Window, int> (direct_hash, direct_equal);
        private Meta.SizeChange? which_change = null;
        private Mtk.Rectangle old_rect_size_change;
        private Clutter.Actor? latest_window_snapshot;

        private GLib.Settings behavior_settings;
        private GLib.Settings new_behavior_settings;

        construct {
#if !HAS_MUTTER48
            info = Meta.PluginInfo () {name = "Gala", version = Config.VERSION, author = "Gala Developers",
                license = "GPLv3", description = "A nice elementary window manager"};
#endif

            behavior_settings = new GLib.Settings ("io.elementary.desktop.wm.behavior");
            new_behavior_settings = new GLib.Settings ("io.elementary.desktop.wm.behavior");

            //Make it start watching the settings daemon bus
            Drawing.StyleManager.get_instance ();
        }

        public override void start () {
            ShellClientsManager.init (this);
            BlurManager.init (this);
            daemon_manager = new DaemonManager (get_display ());

            show_stage ();

            init_a11y ();

            AccessDialog.watch_portal ();


            filter_manager = new FilterManager (this);
            notifications_manager = new NotificationsManager ();
            screenshot_manager = new ScreenshotManager (this, notifications_manager, filter_manager);
            DBus.init (this, notifications_manager, screenshot_manager);

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

            notification_stack = new NotificationStack (display);

#if HAS_MUTTER48
            stage = display.get_compositor ().get_stage () as Clutter.Stage;
#else
            stage = display.get_stage () as Clutter.Stage;
#endif
            var background_settings = new GLib.Settings ("org.gnome.desktop.background");
            var color = background_settings.get_string ("primary-color");
#if HAS_MUTTER47
            stage.background_color = Cogl.Color.from_string (color);
#else
            stage.background_color = Clutter.Color.from_string (color);
#endif

            unowned var laters = display.get_compositor ().get_laters ();
            laters.add (Meta.LaterType.BEFORE_REDRAW, () => {
                WorkspaceManager.init (this);
                return false;
            });

            /* our layer structure:
             * stage
             * + system background
             * + ui group
             * +-- window group
             * +---- background manager
             * +-- top window group
             * +-- multitasking view
             * +-- window switcher
             * +-- window overview
             * +-- shell group
             * +-- feedback group (e.g. DND icons)
             * +-- pointer locator
             * +-- dwell click timer
             * +-- session locker
             */

            system_background = new SystemBackground (display);

            system_background.background_actor.add_constraint (new Clutter.BindConstraint (stage,
                Clutter.BindCoordinate.ALL, 0));
            stage.insert_child_below (system_background.background_actor, null);

            ui_group = new Clutter.Actor ();
            update_ui_group_size ();
            stage.add_child (ui_group);

#if HAS_MUTTER48
            window_group = display.get_compositor ().get_window_group ();
#else
            window_group = display.get_window_group ();
#endif
            stage.remove_child (window_group);
            ui_group.add_child (window_group);

            background_group = new BackgroundContainer (display);
            ((BackgroundContainer)background_group).show_background_menu.connect (daemon_manager.show_background_menu);
            window_group.add_child (background_group);
            window_group.set_child_below_sibling (background_group, null);

#if HAS_MUTTER48
            top_window_group = display.get_compositor ().get_top_window_group ();
#else
            top_window_group = display.get_top_window_group ();
#endif
            stage.remove_child (top_window_group);
            ui_group.add_child (top_window_group);

            // Initialize plugins and add default components if no plugin overrides them
            unowned var plugin_manager = PluginManager.get_default ();
            plugin_manager.initialize (this);
            plugin_manager.regions_changed.connect (update_input_area);

            multitasking_view = new MultitaskingView (this);
            ui_group.add_child (multitasking_view);

            if (plugin_manager.window_switcher_provider == null) {
                window_switcher = new WindowSwitcher (this);
                ui_group.add_child (window_switcher);

                Meta.KeyBinding.set_custom_handler ("switch-applications", window_switcher.handle_switch_windows);
                Meta.KeyBinding.set_custom_handler ("switch-applications-backward", window_switcher.handle_switch_windows);
                Meta.KeyBinding.set_custom_handler ("switch-windows", window_switcher.handle_switch_windows);
                Meta.KeyBinding.set_custom_handler ("switch-windows-backward", window_switcher.handle_switch_windows);
                Meta.KeyBinding.set_custom_handler ("switch-group", window_switcher.handle_switch_windows);
                Meta.KeyBinding.set_custom_handler ("switch-group-backward", window_switcher.handle_switch_windows);
            }

            if (plugin_manager.window_overview_provider == null
                || (window_overview = (plugin_manager.get_plugin (plugin_manager.window_overview_provider) as ActivatableComponent)) == null
            ) {
                window_overview = new WindowOverview (this);
                ui_group.add_child ((Clutter.Actor) window_overview);
            }

            // Add the remaining components that should be on top
            shell_group = new Clutter.Actor ();
            ui_group.add_child (shell_group);

            var feedback_group = display.get_compositor ().get_feedback_group ();
            stage.remove_child (feedback_group);
            ui_group.add_child (feedback_group);

            pointer_locator = new PointerLocator (display);
            ui_group.add_child (pointer_locator);
            ui_group.add_child (new DwellClickTimer (display));

            var session_locker = new SessionLocker (this);
            ui_group.add_child (session_locker);

            screensaver = new ScreenSaverManager (session_locker);
            // Due to a bug which enables access to the stage when using multiple monitors
            // in the screensaver, we have to listen for changes and make sure the input area
            // is set to NONE when we are in locked mode
            screensaver.active_changed.connect (update_input_area);

            /*keybindings*/
            var keybinding_settings = new GLib.Settings ("io.elementary.desktop.wm.keybindings");

            display.add_keybinding ("switch-to-workspace-first", keybinding_settings, IGNORE_AUTOREPEAT, handle_switch_to_workspace_end);
            display.add_keybinding ("switch-to-workspace-last", keybinding_settings, IGNORE_AUTOREPEAT, handle_switch_to_workspace_end);
            display.add_keybinding ("move-to-workspace-first", keybinding_settings, IGNORE_AUTOREPEAT, handle_move_to_workspace_end);
            display.add_keybinding ("move-to-workspace-last", keybinding_settings, IGNORE_AUTOREPEAT, handle_move_to_workspace_end);
            display.add_keybinding ("cycle-workspaces-next", keybinding_settings, NONE, handle_cycle_workspaces);
            display.add_keybinding ("cycle-workspaces-previous", keybinding_settings, NONE, handle_cycle_workspaces);
            display.add_keybinding ("panel-main-menu", keybinding_settings, IGNORE_AUTOREPEAT, handle_applications_menu);

            display.add_keybinding ("toggle-multitasking-view", keybinding_settings, IGNORE_AUTOREPEAT, () => {
                if (multitasking_view.is_opened ()) {
                    multitasking_view.close ();
                } else {
                    multitasking_view.open ();
                }
            });

            display.add_keybinding ("expose-all-windows", keybinding_settings, IGNORE_AUTOREPEAT, () => {
                if (window_overview.is_opened ()) {
                    window_overview.close ();
                } else {
                    window_overview.open ();
                }
            });

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

            unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
            monitor_manager.monitors_changed.connect (update_ui_group_size);

            hot_corner_manager = new HotCornerManager (this, behavior_settings, new_behavior_settings);
            hot_corner_manager.on_configured.connect (update_input_area);
            hot_corner_manager.configure ();

            zoom = new Zoom (this);

            update_input_area ();

            var scroll_action = new SuperScrollAction (display);
            scroll_action.triggered.connect (handle_super_scroll);
            stage.add_action_full ("wm-super-scroll-action", CAPTURE, scroll_action);

            display.window_created.connect ((window) =>
                InternalUtils.wait_for_window_actor_visible (window, check_shell_window)
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

        private void update_ui_group_size () {
            unowned var display = get_display ();

            int max_width = 0;
            int max_height = 0;

            var num_monitors = display.get_n_monitors ();
            for (int i = 0; i < num_monitors; i++) {
                var geom = display.get_monitor_geometry (i);
                var total_width = geom.x + geom.width;
                var total_height = geom.y + geom.height;

                max_width = (max_width > total_width) ? max_width : total_width;
                max_height = (max_height > total_height) ? max_height : total_height;
            }

            ui_group.set_size (max_width, max_height);
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
            multitasking_view.switch_to_next_workspace (direction);
        }

        private void update_input_area () {
            unowned Meta.Display display = get_display ();

            if (screensaver != null) {
                try {
                    if (screensaver.get_active ()) {
                        InternalUtils.set_input_area (display, InputArea.NONE);
                        return;
                    }
                } catch (Error e) {
                    // the screensaver object apparently won't be null even though
                    // it is unavailable. This error will be thrown however, so we
                    // can just ignore it, because if it is thrown, the screensaver
                    // is unavailable.
                }
            }

            if (is_modal ()) {
                var area = multitasking_view.is_opened () ? InputArea.MULTITASKING_VIEW : InputArea.FULLSCREEN;
                InternalUtils.set_input_area (display, area);
            } else {
                InternalUtils.set_input_area (display, InputArea.DEFAULT);
            }
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

            multitasking_view.move_window (window, workspace);
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

            update_input_area ();

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

            update_input_area ();

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

            if (!is_modal () || modal_stack.peek_head ().grab != null || display.focus_window == null ||
                ShellClientsManager.get_instance ().is_positioned_window (display.focus_window)
            ) {
                return;
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

        private void set_grab_trigger (Meta.Window window, Meta.GrabOp op) {
            var proxy = push_modal (stage, true);

            ulong handler = 0;
            handler = stage.captured_event.connect ((event) => {
                if (event.get_type () == MOTION || event.get_type () == ENTER ||
                    event.get_type () == TOUCHPAD_HOLD || event.get_type () == TOUCH_BEGIN) {
                    window.begin_grab_op (
                        op,
                        event.get_device (),
                        event.get_event_sequence (),
                        event.get_time ()
#if HAS_MUTTER46
                        , null
#endif
                    );
                } else if (event.get_type () == LEAVE) {
                    /* We get leave emitted when beginning a grab op, so we have
                       to filter it in order to avoid disconnecting and popping twice */
                    return Clutter.EVENT_PROPAGATE;
                }

                pop_modal (proxy);
                stage.disconnect (handler);

                return Clutter.EVENT_PROPAGATE;
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
                    if (multitasking_view.is_opened ())
                        multitasking_view.close ();
                    else
                        multitasking_view.open ();
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
                    if (current != null && current.allows_move ())
#if HAS_MUTTER46
                        set_grab_trigger (current, KEYBOARD_MOVING);
#else
                        current.begin_grab_op (Meta.GrabOp.KEYBOARD_MOVING, null, null, Meta.CURRENT_TIME);
#endif
                    break;
                case ActionType.START_RESIZE_CURRENT:
                    if (current != null && current.allows_resize ())
#if HAS_MUTTER46
                        set_grab_trigger (current, KEYBOARD_RESIZING_UNKNOWN);
#else
                        current.begin_grab_op (Meta.GrabOp.KEYBOARD_RESIZING_UNKNOWN, null, null, Meta.CURRENT_TIME);
#endif
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
                    switch_to_next_workspace (Meta.MotionDirection.LEFT, Meta.CURRENT_TIME);
                    break;
                case ActionType.SWITCH_TO_WORKSPACE_NEXT:
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
                    if (window_overview == null) {
                        break;
                    }

                    if (window_overview.is_opened ()) {
                        window_overview.close ();
                    } else {
                        window_overview.open ();
                    }
                    critical ("Window overview is deprecated");
                    break;
                case ActionType.WINDOW_OVERVIEW_ALL:
                    if (window_overview == null) {
                        break;
                    }

                    if (window_overview.is_opened ()) {
                        window_overview.close ();
                    } else {
                        window_overview.open ();
                    }
                    break;
                case ActionType.SWITCH_TO_WORKSPACE_LAST:
                    unowned var manager = display.get_workspace_manager ();
                    unowned var workspace = manager.get_workspace_by_index (manager.get_n_workspaces () - 1);
                    workspace.activate (display.get_current_time ());
                    break;
                case ActionType.SCREENSHOT_CURRENT:
                    screenshot_manager.handle_screenshot_current_window_shortcut.begin (false);
                    break;
                default:
                    warning ("Trying to run unknown action");
                    break;
            }
        }

        public override void show_window_menu (Meta.Window window, Meta.WindowMenuType menu, int x, int y) {
            switch (menu) {
                case Meta.WindowMenuType.WM:
                    if (NotificationStack.is_notification (window)) {
                        return;
                    }

                    WindowFlags flags = WindowFlags.NONE;
                    if (window.can_minimize ())
                        flags |= WindowFlags.CAN_HIDE;

                    if (window.can_maximize ())
                        flags |= WindowFlags.CAN_MAXIMIZE;

#if HAS_MUTTER49
                    if (window.is_maximized ())
                        flags |= WindowFlags.IS_MAXIMIZED;

                    if (window.maximized_vertically && !window.maximized_horizontally)
                        flags |= WindowFlags.IS_TILED;
#else
                    var maximize_flags = window.get_maximized ();
                    if (maximize_flags > 0) {
                        flags |= WindowFlags.IS_MAXIMIZED;

                        if (Meta.MaximizeFlags.VERTICAL in maximize_flags && !(Meta.MaximizeFlags.HORIZONTAL in maximize_flags)) {
                            flags |= WindowFlags.IS_TILED;
                        }
                    }
#endif

                    if (window.allows_move ())
                        flags |= WindowFlags.ALLOWS_MOVE;

                    if (window.allows_resize ())
                        flags |= WindowFlags.ALLOWS_RESIZE;

                    if (window.is_above ())
                        flags |= WindowFlags.ALWAYS_ON_TOP;

                    if (window.on_all_workspaces)
                        flags |= WindowFlags.ON_ALL_WORKSPACES;

                    if (window.can_close ())
                        flags |= WindowFlags.CAN_CLOSE;

                    unowned var workspace = window.get_workspace ();
                    if (workspace != null) {
                        unowned var manager = window.display.get_workspace_manager ();
                        var workspace_index = workspace.workspace_index;
                        if (workspace_index != 0) {
                            flags |= WindowFlags.ALLOWS_MOVE_LEFT;
                        }

                        if (workspace_index != manager.n_workspaces - 2 || Utils.get_n_windows (workspace) != 1) {
                            flags |= WindowFlags.ALLOWS_MOVE_RIGHT;
                        }
                    }

                    daemon_manager.show_window_menu.begin (flags, x, y);
                    break;
                case Meta.WindowMenuType.APP:
                    // FIXME we don't have any sort of app menus
                    break;
            }
        }

        public override void show_tile_preview (Meta.Window window, Mtk.Rectangle tile_rect, int tile_monitor_number) {
            if (tile_preview == null) {
                tile_preview = new Clutter.Actor ();
                var rgba = Drawing.StyleManager.get_instance ().theme_accent_color;
                tile_preview.background_color = {
                    (uint8)(255.0 * rgba.red),
                    (uint8)(255.0 * rgba.green),
                    (uint8)(255.0 * rgba.blue),
                    (uint8)(255.0 * rgba.alpha)
                };
                tile_preview.opacity = 0U;

                window_group.add_child (tile_preview);
            } else if (tile_preview.is_visible ()) {
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

            var duration = AnimationDuration.SNAP / 2U;

            var rect = window.get_frame_rect ();
            tile_preview.set_position (rect.x, rect.y);
            tile_preview.set_size (rect.width, rect.height);
            tile_preview.show ();

            if (Meta.Prefs.get_gnome_animations ()) {
                tile_preview.save_easing_state ();
                tile_preview.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
                tile_preview.set_easing_duration (duration);
                tile_preview.opacity = 255U;
                tile_preview.set_position (tile_rect.x, tile_rect.y);
                tile_preview.set_size (tile_rect.width, tile_rect.height);
                tile_preview.restore_easing_state ();
            } else {
                tile_preview.opacity = 255U;
            }
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

        private void check_shell_window (Meta.WindowActor actor) {
            unowned var window = actor.get_meta_window ();
            if (ShellClientsManager.get_instance ().is_positioned_window (window)) {
                InternalUtils.clutter_actor_reparent (actor, shell_group);
            }

            if (NotificationStack.is_notification (window)) {
                notification_stack.show_notification (actor);
            }
        }

        /*
         * effects
         */

        // must wait for size_changed to get updated frame_rect
        // as which_change is not passed to size_changed, save it as instance variable
        public override void size_change (Meta.WindowActor actor, Meta.SizeChange which_change_local, Mtk.Rectangle old_frame_rect, Mtk.Rectangle old_buffer_rect) {
            which_change = which_change_local;
            old_rect_size_change = old_frame_rect;

            if (Meta.Prefs.get_gnome_animations ()) {
                latest_window_snapshot = Utils.get_window_actor_snapshot (actor, old_frame_rect);
            }
        }

        // size_changed gets called after frame_rect has updated
        public override void size_changed (Meta.WindowActor actor) {
            if (which_change == null) {
                return;
            }

            unowned var window = actor.get_meta_window ();
            var new_rect = window.get_frame_rect ();

            switch (which_change) {
                case Meta.SizeChange.MAXIMIZE:
                case Meta.SizeChange.FULLSCREEN:
                    // don't animate resizing of two tiled windows with mouse drag
                    if (window.get_tile_match () != null && !window.maximized_horizontally) {
                        var old_end = old_rect_size_change.x + old_rect_size_change.width;
                        var new_end = new_rect.x + new_rect.width;

                        // a tiled window is just resized (and not moved) if its start_x or its end_x stays the same
                        if (old_rect_size_change.x == new_rect.x || old_end == new_end) {
                            break;
                        }
                    }

                    maximize (actor, new_rect.x, new_rect.y, new_rect.width, new_rect.height);
                    break;
                case Meta.SizeChange.UNMAXIMIZE:
                case Meta.SizeChange.UNFULLSCREEN:
                    unmaximize (actor, new_rect.x, new_rect.y, new_rect.width, new_rect.height);
                    break;
                default:
                    break;
            }

            which_change = null;
            size_change_completed (actor);
        }

        public override void minimize (Meta.WindowActor actor) {
            if (!Meta.Prefs.get_gnome_animations () ||
                actor.get_meta_window ().window_type != Meta.WindowType.NORMAL) {
                minimize_completed (actor);
                return;
            }

            var duration = AnimationDuration.HIDE;

            kill_window_effects (actor);
            minimizing.add (actor);

            int width, height;
            get_display ().get_size (out width, out height);

            Mtk.Rectangle icon = {};
            if (actor.get_meta_window ().get_icon_geometry (out icon)) {
                // Fix icon position and size according to ui scaling factor.
                float ui_scale = get_display ().get_monitor_scale (get_display ().get_monitor_index_for_rect (icon));
                icon.x = Utils.scale_to_int (icon.x, ui_scale);
                icon.y = Utils.scale_to_int (icon.y, ui_scale);
                icon.width = Utils.scale_to_int (icon.width, ui_scale);
                icon.height = Utils.scale_to_int (icon.height, ui_scale);

                float scale_x = (float)icon.width / actor.width;
                float scale_y = (float)icon.height / actor.height;
                float anchor_x = (float)(actor.x - icon.x) / (icon.width - actor.width);
                float anchor_y = (float)(actor.y - icon.y) / (icon.height - actor.height);
                actor.set_pivot_point (anchor_x, anchor_y);

                actor.save_easing_state ();
                actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_EXPO);
                actor.set_easing_duration (duration);
                actor.set_scale (scale_x, scale_y);
                actor.opacity = 0U;
                actor.restore_easing_state ();

                ulong minimize_handler_id = 0UL;
                minimize_handler_id = actor.transitions_completed.connect (() => {
                    actor.disconnect (minimize_handler_id);
                    minimize_completed (actor);
                    minimizing.remove (actor);
                });

            } else {
                actor.set_pivot_point (0.5f, 1.0f);

                actor.save_easing_state ();
                actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_EXPO);
                actor.set_easing_duration (duration);
                actor.set_scale (0.0f, 0.0f);
                actor.opacity = 0U;
                actor.restore_easing_state ();

                ulong minimize_handler_id = 0UL;
                minimize_handler_id = actor.transitions_completed.connect (() => {
                    actor.disconnect (minimize_handler_id);
                    actor.set_pivot_point (0.0f, 0.0f);
                    actor.set_scale (1.0f, 1.0f);
                    actor.opacity = 255U;
                    minimize_completed (actor);
                    minimizing.remove (actor);
                });
            }
        }

        private void maximize (Meta.WindowActor actor, int ex, int ey, int ew, int eh) {
            unowned var window = actor.get_meta_window ();
            if (window.maximized_horizontally && behavior_settings.get_boolean ("move-maximized-workspace")
                || window.fullscreen && behavior_settings.get_boolean ("move-fullscreened-workspace")) {
                move_window_to_next_ws (window);
            }

            kill_window_effects (actor);

            if (!Meta.Prefs.get_gnome_animations () ||
                latest_window_snapshot == null ||
                window.window_type != Meta.WindowType.NORMAL) {
                return;
            }

            var duration = AnimationDuration.SNAP;

            maximizing.add (actor);
            latest_window_snapshot.set_position (old_rect_size_change.x, old_rect_size_change.y);

            ui_group.add_child (latest_window_snapshot);

            // FIMXE that's a hacky part. There is a short moment right after maximized_completed
            //       where the texture is screwed up and shows things it's not supposed to show,
            //       resulting in flashing. Waiting here transparently shortly fixes that issue. There
            //       appears to be no signal that would inform when that moment happens.
            //       We can't spend arbitrary amounts of time transparent since the overlay fades away,
            //       about a third has proven to be a solid time. So this fix will only apply for
            //       durations >= FLASH_PREVENT_TIMEOUT*3
            const int FLASH_PREVENT_TIMEOUT = 80;
            var delay = 0;
            if (FLASH_PREVENT_TIMEOUT <= duration / 3) {
                actor.opacity = 0;
                delay = FLASH_PREVENT_TIMEOUT;
                Timeout.add (FLASH_PREVENT_TIMEOUT, () => {
                    actor.opacity = 255;
                    return false;
                });
            }

            var scale_x = (double) ew / old_rect_size_change.width;
            var scale_y = (double) eh / old_rect_size_change.height;

            latest_window_snapshot.save_easing_state ();
            latest_window_snapshot.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
            latest_window_snapshot.set_easing_duration (duration);
            latest_window_snapshot.set_position (ex, ey);
            latest_window_snapshot.set_scale (scale_x, scale_y);
            latest_window_snapshot.restore_easing_state ();

            // the opacity animation is special, since we have to wait for the
            // FLASH_PREVENT_TIMEOUT to be done before we can safely fade away
            latest_window_snapshot.save_easing_state ();
            latest_window_snapshot.set_easing_delay (delay);
            latest_window_snapshot.set_easing_duration (duration - delay);
            latest_window_snapshot.opacity = 0;
            latest_window_snapshot.restore_easing_state ();

            ulong maximize_old_handler_id = 0;
            maximize_old_handler_id = latest_window_snapshot.transition_stopped.connect ((snapshot, name, is_finished) => {
                snapshot.disconnect (maximize_old_handler_id);

                actor.set_translation (0.0f, 0.0f, 0.0f);

                unowned var parent = snapshot.get_parent ();
                if (parent != null) {
                    parent.remove_child (snapshot);
                }
            });

            latest_window_snapshot = null;

            actor.set_pivot_point (0.0f, 0.0f);
            actor.set_translation (old_rect_size_change.x - ex, old_rect_size_change.y - ey, 0.0f);
            actor.set_scale (1.0f / scale_x, 1.0f / scale_y);

            actor.save_easing_state ();
            actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
            actor.set_easing_duration (duration);
            actor.set_scale (1.0f, 1.0f);
            actor.set_translation (0.0f, 0.0f, 0.0f);
            actor.restore_easing_state ();

            ulong handler_id = 0UL;
            handler_id = actor.transitions_completed.connect (() => {
                actor.disconnect (handler_id);
                maximizing.remove (actor);
            });
        }

        public override void unminimize (Meta.WindowActor actor) {
            if (!Meta.Prefs.get_gnome_animations ()) {
                actor.show ();
                unminimize_completed (actor);
                return;
            }

            var duration = AnimationDuration.HIDE;
            unowned var window = actor.get_meta_window ();

            actor.remove_all_transitions ();
            actor.show ();

            switch (window.window_type) {
                case Meta.WindowType.NORMAL:
                    unminimizing.add (actor);

                    actor.set_pivot_point (0.5f, 1.0f);
                    actor.set_scale (0.01f, 0.1f);
                    actor.opacity = 0U;

                    actor.save_easing_state ();
                    actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_EXPO);
                    actor.set_easing_duration (duration);
                    actor.set_scale (1.0f, 1.0f);
                    actor.opacity = 255U;
                    actor.restore_easing_state ();

                    ulong unminimize_handler_id = 0UL;
                    unminimize_handler_id = actor.transitions_completed.connect (() => {
                        actor.disconnect (unminimize_handler_id);
                        unminimizing.remove (actor);
                        unminimize_completed (actor);
                    });

                    break;
                default:
                    unminimize_completed (actor);
                    break;
            }
        }

        public override void map (Meta.WindowActor actor) {
            unowned var window = actor.get_meta_window ();

            WindowStateSaver.on_map (window);

            if ((window.maximized_horizontally && behavior_settings.get_boolean ("move-maximized-workspace")) ||
                (window.fullscreen && window.is_on_primary_monitor () && behavior_settings.get_boolean ("move-fullscreened-workspace"))) {
                move_window_to_next_ws (window);
            }

            actor.remove_all_transitions ();
            actor.show ();

            // Notifications initial animation is handled by the notification stack
            if (NotificationStack.is_notification (window) || !Meta.Prefs.get_gnome_animations ()) {
                map_completed (actor);
                return;
            }

            switch (window.window_type) {
                case Meta.WindowType.NORMAL:
                    var duration = AnimationDuration.HIDE;
                    if (duration == 0) {
                        map_completed (actor);
                        return;
                    }

                    mapping.add (actor);

                    if (window.maximized_vertically || window.maximized_horizontally) {
                        var outer_rect = window.get_frame_rect ();
                        actor.set_position (outer_rect.x, outer_rect.y);
                    }

                    actor.set_pivot_point (0.5f, 1.0f);
                    actor.set_scale (0.01f, 0.1f);
                    actor.opacity = 0;

                    actor.save_easing_state ();
                    actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_EXPO);
                    actor.set_easing_duration (duration);
                    actor.set_scale (1.0f, 1.0f);
                    actor.opacity = 255U;
                    actor.restore_easing_state ();

                    ulong map_handler_id = 0UL;
                    map_handler_id = actor.transitions_completed.connect (() => {
                        actor.disconnect (map_handler_id);
                        mapping.remove (actor);
                        map_completed (actor);
                    });
                    break;
                case Meta.WindowType.MENU:
                case Meta.WindowType.DROPDOWN_MENU:
                case Meta.WindowType.POPUP_MENU:
                    var duration = AnimationDuration.MENU_MAP;
                    if (duration == 0) {
                        map_completed (actor);
                        return;
                    }

                    mapping.add (actor);

                    actor.opacity = 0;

                    actor.save_easing_state ();
                    actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
                    actor.set_easing_duration (duration);
                    actor.opacity = 255;
                    actor.restore_easing_state ();

                    ulong map_handler_id = 0UL;
                    map_handler_id = actor.transitions_completed.connect (() => {
                        actor.disconnect (map_handler_id);
                        mapping.remove (actor);
                        map_completed (actor);
                    });
                    break;
                case Meta.WindowType.MODAL_DIALOG:
                case Meta.WindowType.DIALOG:

                    mapping.add (actor);

                    actor.set_pivot_point (0.5f, 0.5f);
                    actor.set_scale (1.05f, 1.05f);
                    actor.opacity = 0;

                    actor.save_easing_state ();
                    actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
                    actor.set_easing_duration (200);
                    actor.set_scale (1.0f, 1.0f);
                    actor.opacity = 255U;
                    actor.restore_easing_state ();

                    ulong map_handler_id = 0UL;
                    map_handler_id = actor.transitions_completed.connect (() => {
                        actor.disconnect (map_handler_id);
                        mapping.remove (actor);
                        map_completed (actor);
                    });

                    dim_parent_window (window);

                    break;
                default:
                    map_completed (actor);
                    break;
            }
        }

        public override void destroy (Meta.WindowActor actor) {
            unowned var window = actor.get_meta_window ();

            actor.remove_all_transitions ();

            if (NotificationStack.is_notification (window)) {
                if (Meta.Prefs.get_gnome_animations ()) {
                    destroying.add (actor);
                }

                notification_stack.destroy_notification (actor);

                if (Meta.Prefs.get_gnome_animations ()) {
                    ulong destroy_handler_id = 0UL;
                    destroy_handler_id = actor.transitions_completed.connect (() => {
                        actor.disconnect (destroy_handler_id);
                        destroying.remove (actor);
                        destroy_completed (actor);
                    });
                } else {
                    destroy_completed (actor);
                }

                return;
            }

            if (!Meta.Prefs.get_gnome_animations ()) {
                destroy_completed (actor);

                if (window.window_type == Meta.WindowType.NORMAL) {
                    Utils.clear_window_cache (window);
                }

                return;
            }

            switch (window.window_type) {
                case Meta.WindowType.NORMAL:
                    var duration = AnimationDuration.CLOSE;
                    if (duration == 0) {
                        destroy_completed (actor);
                        return;
                    }

                    destroying.add (actor);

                    actor.set_pivot_point (0.5f, 0.5f);
                    actor.show ();

                    actor.save_easing_state ();
                    actor.set_easing_mode (Clutter.AnimationMode.LINEAR);
                    actor.set_easing_duration (duration);
                    actor.set_scale (0.8f, 0.8f);
                    actor.opacity = 0U;
                    actor.restore_easing_state ();

                    ulong destroy_handler_id = 0UL;
                    destroy_handler_id = actor.transitions_completed.connect (() => {
                        actor.disconnect (destroy_handler_id);
                        destroying.remove (actor);
                        destroy_completed (actor);
                        Utils.clear_window_cache (window);
                    });
                    break;
                case Meta.WindowType.MODAL_DIALOG:
                case Meta.WindowType.DIALOG:
                    destroying.add (actor);

                    actor.set_pivot_point (0.5f, 0.5f);
                    actor.save_easing_state ();
                    actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_QUAD);
                    actor.set_easing_duration (150);
                    actor.set_scale (1.05f, 1.05f);
                    actor.opacity = 0U;
                    actor.restore_easing_state ();

                    ulong destroy_handler_id = 0UL;
                    destroy_handler_id = actor.transitions_completed.connect (() => {
                        actor.disconnect (destroy_handler_id);
                        destroying.remove (actor);
                        destroy_completed (actor);
                    });
                    break;
                default:
                    destroy_completed (actor);
                    break;
            }
        }

        private void unmaximize (Meta.WindowActor actor, int ex, int ey, int ew, int eh) {
            unowned var window = actor.get_meta_window ();
            move_window_to_old_ws (window);

            kill_window_effects (actor);

            if (!Meta.Prefs.get_gnome_animations () ||
                latest_window_snapshot == null ||
                window.window_type != Meta.WindowType.NORMAL) {
                return;
            }

            var duration = AnimationDuration.SNAP;

            float offset_x, offset_y;
            var unmaximized_window_geometry = WindowListener.get_default ().get_unmaximized_state_geometry (window);

            if (unmaximized_window_geometry != null) {
                offset_x = unmaximized_window_geometry.outer.x - unmaximized_window_geometry.inner.x;
                offset_y = unmaximized_window_geometry.outer.y - unmaximized_window_geometry.inner.y;
            } else {
                offset_x = 0;
                offset_y = 0;
            }

            unmaximizing.add (actor);

            latest_window_snapshot.set_position (old_rect_size_change.x, old_rect_size_change.y);

            ui_group.add_child (latest_window_snapshot);

            var scale_x = (float) ew / old_rect_size_change.width;
            var scale_y = (float) eh / old_rect_size_change.height;

            latest_window_snapshot.save_easing_state ();
            latest_window_snapshot.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
            latest_window_snapshot.set_easing_duration (duration);
            latest_window_snapshot.set_position (ex, ey);
            latest_window_snapshot.set_scale (scale_x, scale_y);
            latest_window_snapshot.opacity = 0U;
            latest_window_snapshot.restore_easing_state ();

            ulong unmaximize_old_handler_id = 0;
            unmaximize_old_handler_id = latest_window_snapshot.transition_stopped.connect ((snapshot, name, is_finished) => {
                snapshot.disconnect (unmaximize_old_handler_id);

                unowned var parent = snapshot.get_parent ();
                if (parent != null) {
                    parent.remove_child (snapshot);
                }
            });

            latest_window_snapshot = null;

            var buffer_rect = window.get_buffer_rect ();
            var frame_rect = window.get_frame_rect ();
            var real_actor_offset_x = frame_rect.x - buffer_rect.x;
            var real_actor_offset_y = frame_rect.y - buffer_rect.y;

            actor.set_pivot_point (0.0f, 0.0f);
            actor.set_position (ex - real_actor_offset_x, ey - real_actor_offset_y);
            actor.set_translation (-ex + offset_x * (1.0f / scale_x - 1.0f) + old_rect_size_change.x, -ey + offset_y * (1.0f / scale_y - 1.0f) + old_rect_size_change.y, 0.0f);
            actor.set_scale (1.0f / scale_x, 1.0f / scale_y);

            actor.save_easing_state ();
            actor.set_easing_mode (Clutter.AnimationMode.EASE_IN_OUT_QUAD);
            actor.set_easing_duration (duration);
            actor.set_scale (1.0f, 1.0f);
            actor.set_translation (0.0f, 0.0f, 0.0f);
            actor.restore_easing_state ();

            ulong handler_id = 0UL;
            handler_id = actor.transitions_completed.connect (() => {
                actor.disconnect (handler_id);
                unmaximizing.remove (actor);
            });
        }

        private void move_window_to_next_ws (Meta.Window window) {
            unowned var win_ws = window.get_workspace ();

            // Do nothing if the current workspace would be empty
            if (Utils.get_n_windows (win_ws) <= 1) {
                return;
            }

            // Do nothing if window is not on primary monitor
            if (!window.is_on_primary_monitor ()) {
                return;
            }

            var old_ws_index = win_ws.index ();
            var new_ws_index = old_ws_index + 1;
            InternalUtils.insert_workspace_with_window (new_ws_index, window);

            unowned var display = get_display ();
            var time = display.get_current_time ();
            unowned var new_ws = display.get_workspace_manager ().get_workspace_by_index (new_ws_index);
            window.change_workspace (new_ws);
            new_ws.activate_with_focus (window, time);

            if (!(window in ws_assoc)) {
                window.unmanaged.connect (move_window_to_old_ws);
            }

            ws_assoc[window] = old_ws_index;
        }

        private void move_window_to_old_ws (Meta.Window window) {
            unowned var win_ws = window.get_workspace ();

            // Do nothing if the current workspace is populated with other windows
            if (Utils.get_n_windows (win_ws) > 1) {
                return;
            }

            if (!ws_assoc.contains (window)) {
                return;
            }

            var old_ws_index = ws_assoc.get (window);
            var new_ws_index = win_ws.index ();

            unowned var display = get_display ();
            unowned var workspace_manager = display.get_workspace_manager ();
            if (new_ws_index != old_ws_index && old_ws_index < workspace_manager.get_n_workspaces ()) {
                uint time = display.get_current_time ();
                unowned var old_ws = workspace_manager.get_workspace_by_index (old_ws_index);
                window.change_workspace (old_ws);
                old_ws.activate_with_focus (window, time);
            }

            ws_assoc.remove (window);

            window.unmanaged.disconnect (move_window_to_old_ws);
        }

        // Cancel attached animation of an actor and reset it
        private bool end_animation (ref Gee.HashSet<Meta.WindowActor> list, Meta.WindowActor actor) {
            if (!list.contains (actor))
                return false;

            if (actor.is_destroyed ()) {
                list.remove (actor);
                return false;
            }

            actor.remove_all_transitions ();
            actor.opacity = 255U;
            actor.set_scale (1.0f, 1.0f);
            actor.rotation_angle_x = 0.0f;
            actor.set_pivot_point (0.0f, 0.0f);

            list.remove (actor);
            return true;
        }

        public override void kill_window_effects (Meta.WindowActor actor) {
            if (end_animation (ref mapping, actor))
                map_completed (actor);
            if (end_animation (ref unminimizing, actor))
                unminimize_completed (actor);
            if (end_animation (ref minimizing, actor))
                minimize_completed (actor);
            if (end_animation (ref destroying, actor))
                destroy_completed (actor);

            end_animation (ref unmaximizing, actor);
            end_animation (ref maximizing, actor);
        }

        public override void switch_workspace (int from, int to, Meta.MotionDirection direction) {
            switch_workspace_completed ();
        }

        public override void kill_switch_workspace () {
            multitasking_view.kill_switch_workspace ();
        }

        public override void locate_pointer () {
            pointer_locator.show_ripple ();
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
                    break;
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
                default:
                    break;
            }

            var modal_proxy = modal_stack.peek_head ();
            if (modal_proxy == null) {
                return false;
            }

            unowned var filter = modal_proxy.get_keybinding_filter ();
            if (filter == null) {
                return false;
            }

            return filter (binding);
        }

        public bool filter_action (GestureAction action) {
            if (!is_modal ()) {
                return false;
            }

            return modal_stack.peek_head ().filter_action (action);
        }

        public void add_multitasking_view_target (GestureTarget target) {
            multitasking_view.add_target (target);

            if (window_overview is WindowOverview) {
                ((WindowOverview) window_overview).add_target (target);
            }
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

#if !HAS_MUTTER48
        public override unowned Meta.PluginInfo? plugin_info () {
            return info;
        }
#endif
    }
}
