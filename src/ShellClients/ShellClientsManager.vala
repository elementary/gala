/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellClientsManager : Object, GestureTarget {
    private static ShellClientsManager instance;

    public static void init (WindowManagerGala wm, InputMethod im) {
        if (instance != null) {
            return;
        }

        instance = new ShellClientsManager (wm, im);
    }

    public static unowned ShellClientsManager? get_instance () {
        return instance;
    }

    public WindowManagerGala wm { get; construct; }
    public InputMethod im { get; construct; }

    private NotificationsClient notifications_client;
    private ManagedClient[] protocol_clients = {};

    private int starting_panels = 0;

    private GLib.HashTable<Meta.Window, PanelWindow> panel_windows = new GLib.HashTable<Meta.Window, PanelWindow> (null, null);
    private GLib.HashTable<Meta.Window, ExtendedBehaviorWindow> positioned_windows = new GLib.HashTable<Meta.Window, ExtendedBehaviorWindow> (null, null);
    private GLib.HashTable<Meta.Window, MonitorLabelWindow> monitor_label_windows = new GLib.HashTable<Meta.Window, MonitorLabelWindow> (null, null);
    private IBusCandidateWindow? ibus_candidate_window = null;
    private OSKWindow? osk_window = null;

    private ShellClientsManager (WindowManagerGala wm, InputMethod im) {
        Object (wm: wm, im: im);
    }

    construct {
        notifications_client = new NotificationsClient (wm.get_display ());

        start_clients.begin ();

        Timeout.add_seconds_once (5, on_failsafe_timeout);
    }

    private async void start_clients () {
        // Prioritize user config over system
        (unowned string)[] config_dirs = { Environment.get_user_config_dir () };
        foreach (unowned var dir in Environment.get_system_config_dirs ()) {
            config_dirs += dir;
        }

        string? path = null;
        foreach (unowned var dir in config_dirs) {
            var file_path = Path.build_filename (dir, "io.elementary.desktop.wm.shell");
            warning (file_path);
            if (FileUtils.test (file_path, EXISTS)) {
                path = file_path;
                break;
            }
        }

        if (path == null) {
            warning ("No shell config file found.");
            return;
        }

        var file = File.new_for_path (path);

        Bytes bytes;
        try {
            bytes = yield file.load_bytes_async (null, null);
        } catch (Error e) {
            warning ("Failed to load shell config file: %s", e.message);
            return;
        }

        var key_file = new KeyFile ();
        try {
            key_file.load_from_bytes (bytes, NONE);
        } catch (Error e) {
            warning ("Failed to parse shell config file: %s", e.message);
            return;
        }

        foreach (var group in key_file.get_groups ()) {
            try {
                var type = key_file.get_string (group, "session-type");
                if (type != SessionSettings.get_shell_clients_type ()) {
                    continue;
                }
            } catch (Error e) {
                warning ("Failed to check session type for client %s, assuming it should be launched: %s", group, e.message);
            }

            try {
                starting_panels += key_file.get_integer (group, "wait-for-n-panels");
            } catch (Error e) {
                warning ("Failed to check how many panels should be awaited, assuming 0: %s", e.message);
            }

            try {
                var args = key_file.get_string_list (group, "args");
                protocol_clients += new ManagedClient (wm.get_display (), args);
            } catch (Error e) {
                warning ("Failed to load launch args for client %s: %s", group, e.message);
            }
        }
    }

    private void on_failsafe_timeout () {
        if (starting_panels > 0) {
            warning ("%d panels failed to start in time, showing the others", starting_panels);

            starting_panels = 0;
            foreach (var window in panel_windows.get_values ()) {
                window.animate_start ();
            }
        }
    }

    public void set_anchor (Meta.Window window, Pantheon.Desktop.Anchor anchor) {
        if (window in panel_windows) {
            panel_windows[window].anchor = anchor;
            return;
        }

        ManagedClient.make_dock (window);
        // TODO: Return if requested by window that's not a trusted client?

        panel_windows[window] = new PanelWindow (wm, window, anchor);

        if (SessionSettings.is_greeter ()) {
            wm.override_window_group (window, LOCK_SCREEN_SHELL);
        } else {
            wm.override_window_group (window, DESKTOP_SHELL);
        }

        InternalUtils.wait_for_window_actor_visible (window, on_panel_ready);

        // connect_after so we make sure the PanelWindow can destroy its barriers and struts
        window.unmanaging.connect_after ((_window) => panel_windows.remove (_window));
    }

    private void on_panel_ready (Meta.WindowActor actor) {
        if (starting_panels == 0) {
            panel_windows[actor.meta_window].animate_start ();
            return;
        }

        starting_panels--;
        assert (starting_panels >= 0);

        if (starting_panels == 0) {
            foreach (var window in panel_windows.get_values ()) {
                window.animate_start ();
            }
        }
    }

    /**
     * The size given here is only used for the hide mode. I.e. struts
     * and collision detection with other windows use this size. By default
     * or if set to -1 the size of the window is used.
     *
     * TODO: Maybe use for strut only?
     */
    public void set_size (Meta.Window window, int width, int height) {
        if (!(window in panel_windows)) {
            warning ("Set anchor for window before size.");
            return;
        }

        panel_windows[window].set_size (width, height);
    }

    public void set_hide_mode (Meta.Window window, Pantheon.Desktop.HideMode hide_mode) {
        if (!(window in panel_windows)) {
            warning ("Set anchor for window before hide mode.");
            return;
        }

        panel_windows[window].hide_mode = hide_mode;
    }

    public void request_visible_in_multitasking_view (Meta.Window window) {
        if (!(window in panel_windows)) {
            warning ("Set anchor for window before visible in multitasking view.");
            return;
        }

        panel_windows[window].request_visible_in_multitasking_view ();
    }

    public void make_centered (Meta.Window window) requires (!is_itself_shell_window (window)) {
        positioned_windows[window] = new ExtendedBehaviorWindow (window);

        // connect_after so we make sure that any queued move is unqueued
        window.unmanaging.connect_after ((_window) => positioned_windows.remove (_window));
    }

    public void make_modal (Meta.Window window, bool dim) requires (window in positioned_windows) {
        positioned_windows[window].make_modal (dim);

        wm.override_window_group (window, MODAL);
    }

    public void make_monitor_label (Meta.Window window, int monitor_index) requires (!is_itself_shell_window (window)) {
        if (monitor_index < 0 || monitor_index > wm.get_display ().get_n_monitors ()) {
            warning ("Invalid monitor index provided: %d", monitor_index);
            return;
        }

        monitor_label_windows[window] = new MonitorLabelWindow (window, monitor_index);

        wm.override_window_group (window, DESKTOP_SHELL);

        // connect_after so we make sure that any queued move is unqueued
        window.unmanaging.connect_after ((_window) => monitor_label_windows.remove (_window));
    }

    public void make_ibus_candidate_window (Meta.Window window) requires (ibus_candidate_window == null) {
        ibus_candidate_window = new IBusCandidateWindow (im, window);

        wm.override_window_group (window, OVERLAY);

        window.unmanaged.connect_after (() => ibus_candidate_window = null);
    }

    public void make_greeter (Meta.Window window) {
        ManagedClient.make_desktop (window);

        wm.override_window_group (window, LOCK_SCREEN);
    }

    public void make_osk_window (Meta.Window window) requires (osk_window == null) {
        osk_window = new OSKWindow (im, window);

        wm.override_window_group (window, OVERLAY);

        window.unmanaged.connect_after (() => osk_window = null);
    }

    public void propagate (UpdateType update_type, GestureAction action, double progress) {
        foreach (var window in positioned_windows.get_values ()) {
            window.propagate (update_type, action, progress);
        }

        foreach (var window in panel_windows.get_values ()) {
            window.propagate (update_type, action, progress);
        }
    }

    public bool is_itself_shell_window (Meta.Window window) {
        return (
            (window in positioned_windows && positioned_windows[window].modal) ||
            (window in panel_windows) ||
            (window in monitor_label_windows) ||
            NotificationStack.is_notification (window) ||
            window == ibus_candidate_window?.window ||
            window == osk_window?.window
        );
    }

    /**
     * Whether the given window is a shell window. A shell window is a window that's
     * part of the desktop shell itself and should be completely ignored by other components.
     * It is entirely managed by Gala, always above everything else, and manages hiding
     * in e.g. multitasking view itself. This also applies to transient windows of shell windows.
     * Note that even if `false` is returned the window might still be in part managed by gala
     * e.g. for centered windows.
     */
    public bool is_shell_window (Meta.Window window) {
        bool positioned = is_itself_shell_window (window);
        window.foreach_ancestor ((ancestor) => {
            if (is_itself_shell_window (ancestor)) {
                positioned = true;
            }

            return !positioned;
        });

        return positioned;
    }

    public bool is_system_modal_dimmed (Meta.Window window) requires (
        window in positioned_windows && positioned_windows[window].modal
    ) {
        return positioned_windows[window].dim;
    }

    public Mtk.Rectangle? get_shell_client_rect () {
        foreach (var client in panel_windows.get_values ()) {
            if (client.visible_in_multitasking_view) {
                return client.get_custom_window_rect ();
            }
        }
        return null;
    }
}
