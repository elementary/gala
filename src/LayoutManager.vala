/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.LayoutManager : Object {
    public Meta.Display display { private get; construct; }
    public DaemonManager daemon_manager { private get; construct; }

    public Clutter.Stage stage { get; private set; }
    public Clutter.Actor ui_group { get; private set; }
    public Clutter.Actor window_group { get; private set; }
    public Meta.BackgroundGroup background_group { get; private set; }
    public Clutter.Actor top_window_group { get; private set; }

    public MultitaskingView multitasking_view { get; private set; }
    public WindowOverview window_overview { get; private set; }
    public LockScreen lock_screen { get; private set; }
    public SessionLocker session_locker { get; private set; }
    public PointerLocator pointer_locator { get; private set; }

    private SystemBackground system_background;
    private WindowSwitcher window_switcher;
    private Clutter.Actor shell_group;
    private Clutter.Actor menu_group;
    private ModalGroup modal_group;
    private Clutter.Actor overlay_group;

    public LayoutManager (Meta.Display display, DaemonManager daemon_manager) {
        Object (display: display, daemon_manager: daemon_manager);
    }

    construct {
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
         * +-- desktop shell group
         * +-- menu group
         * +-- lock screen // NOTE: Everything below the lock screen can be accessed without authentication
         * +---- window group
         * +---- shell group
         * +-- modal group
         * +-- overlay group (e.g. ibus popup, osk, etc.)
         * +-- feedback group (e.g. DND icons)
         * +-- pointer locator
         * +-- dwell click timer
         * +-- session locker
         */

#if HAS_MUTTER48
        stage = (Clutter.Stage) display.get_compositor ().get_stage ();
#else
        stage = (Clutter.Stage) display.get_stage ();
#endif
        var background_settings = new GLib.Settings ("org.gnome.desktop.background");
        var color = background_settings.get_string ("primary-color");
#if HAS_MUTTER47
        stage.background_color = Cogl.Color.from_string (color);
#else
        stage.background_color = Clutter.Color.from_string (color);
#endif
        system_background = new SystemBackground (display);

        system_background.background_actor.add_constraint (
            new Clutter.BindConstraint (stage, ALL, 0)
        );
        stage.insert_child_below (system_background.background_actor, null);

        ui_group = new Clutter.Actor ();
        update_ui_group_size ();
        stage.add_child (ui_group);

        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update_ui_group_size);

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
    }

    public void init_ui (WindowManager wm) {
        window_group.add_child (new WindowMaximizer (wm));

        multitasking_view = new MultitaskingView (wm);
        ui_group.add_child (multitasking_view);

        // Add default window switcher if no plugin overrides it
        unowned var plugin_manager = PluginManager.get_default ();
        if (plugin_manager.window_switcher_provider == null) {
            window_switcher = new WindowSwitcher (wm);
            ui_group.add_child (window_switcher);

            Meta.KeyBinding.set_custom_handler ("switch-applications", window_switcher.handle_switch_windows);
            Meta.KeyBinding.set_custom_handler ("switch-applications-backward", window_switcher.handle_switch_windows);
            Meta.KeyBinding.set_custom_handler ("switch-windows", window_switcher.handle_switch_windows);
            Meta.KeyBinding.set_custom_handler ("switch-windows-backward", window_switcher.handle_switch_windows);
            Meta.KeyBinding.set_custom_handler ("switch-group", window_switcher.handle_switch_windows);
            Meta.KeyBinding.set_custom_handler ("switch-group-backward", window_switcher.handle_switch_windows);
        }

        window_overview = new WindowOverview (wm);
        ui_group.add_child (window_overview);

        shell_group = new Clutter.Actor ();
        ui_group.add_child (shell_group);

        menu_group = new Clutter.Actor ();
        ui_group.add_child (menu_group);

        lock_screen = new LockScreen (wm);
        lock_screen.add_constraint (new Clutter.BindConstraint (stage, SIZE, 0));
        ui_group.add_child (lock_screen);

        modal_group = new ModalGroup (wm, ShellClientsManager.get_instance ());
        modal_group.add_constraint (new Clutter.BindConstraint (stage, SIZE, 0));
        ui_group.add_child (modal_group);

        overlay_group = new Clutter.Actor ();
        ui_group.add_child (overlay_group);

        var feedback_group = display.get_compositor ().get_feedback_group ();
        stage.remove_child (feedback_group);
        ui_group.add_child (feedback_group);

        pointer_locator = new PointerLocator (display);
        ui_group.add_child (pointer_locator);

        ui_group.add_child (new DwellClickTimer (display));

        session_locker = new SessionLocker (wm);
        ui_group.add_child (session_locker);
    }

    private void update_ui_group_size () {
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

    public void change_window_group (Meta.WindowActor actor, WindowGroup new_group) {
        InternalUtils.clutter_actor_reparent (actor, get_window_group_actor (new_group));
    }

    private Clutter.Actor get_window_group_actor (WindowGroup group) {
        switch (group) {
            case DESKTOP_SHELL: return shell_group;
            case MENU: return menu_group;
            case LOCK_SCREEN: return lock_screen.window_group;
            case LOCK_SCREEN_SHELL: return lock_screen.shell_group;
            case MODAL: return modal_group.window_group;
            case OVERLAY: return overlay_group;
            default: assert_not_reached ();
        }
    }
}
