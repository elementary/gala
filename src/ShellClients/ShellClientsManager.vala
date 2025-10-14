/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellClientsManager : Object, GestureTarget {
    private static ShellClientsManager instance;

    public static void init (WindowManager wm) {
        if (instance != null) {
            return;
        }

        instance = new ShellClientsManager (wm);
    }

    public static unowned ShellClientsManager? get_instance () {
        return instance;
    }

    public WindowManager wm { get; construct; }

    private NotificationsClient notifications_client;
    private ManagedClient[] protocol_clients = {};

    private int starting_panels = 0;

    private GLib.HashTable<Meta.Window, PanelWindow> panel_windows = new GLib.HashTable<Meta.Window, PanelWindow> (null, null);
    private GLib.HashTable<Meta.Window, ExtendedBehaviorWindow> positioned_windows = new GLib.HashTable<Meta.Window, ExtendedBehaviorWindow> (null, null);

    private ShellClientsManager (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        notifications_client = new NotificationsClient (wm.get_display ());

        start_clients.begin ();

        if (!Meta.Util.is_wayland_compositor ()) {
            wm.get_display ().window_created.connect ((window) => {
                window.notify["mutter-hints"].connect ((obj, pspec) => parse_mutter_hints ((Meta.Window) obj));
                parse_mutter_hints (window);
            });
        }

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
            if (!Meta.Util.is_wayland_compositor ()) {
                try {
                    if (!key_file.get_boolean (group, "launch-on-x")) {
                        continue;
                    }
                } catch (Error e) {
                    warning ("Failed to check whether client should be launched on x, assuming yes: %s", e.message);
                }
            }

            try {
                var args = key_file.get_string_list (group, "args");
                protocol_clients += new ManagedClient (wm.get_display (), args);
            } catch (Error e) {
                warning ("Failed to load launch args for client %s: %s", group, e.message);
            }
        }

        starting_panels = protocol_clients.length;
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

    public void make_dock (Meta.Window window) {
#if HAS_MUTTER49
        window.set_type (Meta.WindowType.DOCK);
#else
        if (Meta.Util.is_wayland_compositor ()) {
            make_dock_wayland (window);
        } else {
            make_dock_x11 (window);
        }
#endif
    }

#if !HAS_MUTTER49
    private void make_dock_wayland (Meta.Window window) requires (Meta.Util.is_wayland_compositor ()) {
        foreach (var client in protocol_clients) {
            if (client.wayland_client.owns_window (window)) {
#if HAS_MUTTER46
                client.wayland_client.make_dock (window);
#endif
                break;
            }
        }
    }

    private void make_dock_x11 (Meta.Window window) requires (!Meta.Util.is_wayland_compositor ()) {
        unowned var x11_display = wm.get_display ().get_x11_display ();

#if HAS_MUTTER46
        var x_window = x11_display.lookup_xwindow (window);
#else
        var x_window = window.get_xwindow ();
#endif
        // gtk3's gdk_x11_window_set_type_hint() is used as a reference
        unowned var xdisplay = x11_display.get_xdisplay ();
        var atom = xdisplay.intern_atom ("_NET_WM_WINDOW_TYPE", false);
        var dock_atom = xdisplay.intern_atom ("_NET_WM_WINDOW_TYPE_DOCK", false);

        // (X.Atom) 4 is XA_ATOM
        // 32 is format
        // 0 means replace
        xdisplay.change_property (x_window, atom, (X.Atom) 4, 32, 0, (uchar[]) dock_atom, 1);
    }
#endif

    public void set_anchor (Meta.Window window, Pantheon.Desktop.Anchor anchor) {
        if (window in panel_windows) {
            panel_windows[window].anchor = anchor;
            return;
        }

        make_dock (window);
        // TODO: Return if requested by window that's not a trusted client?

        panel_windows[window] = new PanelWindow (wm, window, anchor);

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
            warning ("Set anchor for window before visible in mutltiasking view.");
            return;
        }

        panel_windows[window].request_visible_in_multitasking_view ();
    }

    public void make_centered (Meta.Window window) requires (!is_itself_positioned (window)) {
        positioned_windows[window] = new ExtendedBehaviorWindow (window);

        // connect_after so we make sure that any queued move is unqueued
        window.unmanaging.connect_after ((_window) => positioned_windows.remove (_window));
    }

    public void make_modal (Meta.Window window, bool dim) requires (window in positioned_windows) {
        positioned_windows[window].make_modal (dim);
    }

    public void propagate (UpdateType update_type, GestureAction action, double progress) {
        foreach (var window in positioned_windows.get_values ()) {
            window.propagate (update_type, action, progress);
        }

        foreach (var window in panel_windows.get_values ()) {
            window.propagate (update_type, action, progress);
        }
    }

    public bool is_itself_positioned (Meta.Window window) {
        return (window in positioned_windows) || (window in panel_windows) || NotificationStack.is_notification (window);
    }

    public bool is_positioned_window (Meta.Window window) {
        bool positioned = is_itself_positioned (window);
        window.foreach_ancestor ((ancestor) => {
            if (is_itself_positioned (ancestor)) {
                positioned = true;
            }

            return !positioned;
        });

        return positioned;
    }

    private bool is_itself_system_modal (Meta.Window window) {
        return (window in positioned_windows) && positioned_windows[window].modal;
    }

    public bool is_system_modal_window (Meta.Window window) {
        var modal = is_itself_system_modal (window);
        window.foreach_ancestor ((ancestor) => {
            if (is_itself_system_modal (ancestor)) {
                modal = true;
            }

            return !modal;
        });

        return modal;
    }

    public bool is_system_modal_dimmed (Meta.Window window) {
        return is_itself_system_modal (window) && positioned_windows[window].dim;
    }

    //X11 only
    private void parse_mutter_hints (Meta.Window window) requires (!Meta.Util.is_wayland_compositor ()) {
        if (window.mutter_hints == null) {
            return;
        }

        var mutter_hints = window.mutter_hints.split (":");
        foreach (var mutter_hint in mutter_hints) {
            var split = mutter_hint.split ("=");

            if (split.length != 2) {
                continue;
            }

            var key = split[0];
            var val = split[1];

            switch (key) {
                case "anchor":
                    int meta_side_parsed; // Will be used as Meta.Side which is a 4 value bitfield so check bounds for that
                    if (int.try_parse (val, out meta_side_parsed) && 0 <= meta_side_parsed && meta_side_parsed <= 15) {
                        //FIXME: Next major release change dock and wingpanel calls to get rid of this
                        Pantheon.Desktop.Anchor parsed = TOP;
                        switch ((Meta.Side) meta_side_parsed) {
                            case BOTTOM:
                                parsed = BOTTOM;
                                break;

                            case LEFT:
                                parsed = LEFT;
                                break;

                            case RIGHT:
                                parsed = RIGHT;
                                break;

                            default:
                                break;
                        }

                        set_anchor (window, parsed);
                        // We need to set a second time because the intention is to call this before the window is shown which it is on wayland
                        // but on X the window was already shown when we get here so we have to call again to instantly apply it.
                        set_anchor (window, parsed);
                    } else {
                        warning ("Failed to parse %s as anchor", val);
                    }
                    break;

                case "hide-mode":
                    int parsed; // Will be used as Pantheon.Desktop.HideMode which is a 5 value enum so check bounds for that
                    if (int.try_parse (val, out parsed) && 0 <= parsed && parsed <= 4) {
                        set_hide_mode (window, parsed);
                    } else {
                        warning ("Failed to parse %s as hide mode", val);
                    }
                    break;

                case "size":
                    var split_val = val.split (",");
                    if (split_val.length != 2) {
                        break;
                    }
                    int parsed_width, parsed_height = 0; //set to 0 because vala doesn't realize height will be set too
                    if (int.try_parse (split_val[0], out parsed_width) && int.try_parse (split_val[1], out parsed_height)) {
                        set_size (window, parsed_width, parsed_height);
                    } else {
                        warning ("Failed to parse %s as width and height", val);
                    }
                    break;

                case "visible-in-multitasking-view":
                    request_visible_in_multitasking_view (window);
                    break;

                case "centered":
                    make_centered (window);
                    break;

                case "restore-previous-region":
                    set_restore_previous_x11_region (window);
                    break;

                default:
                    break;
            }
        }
    }

    private void set_restore_previous_x11_region (Meta.Window window)
    requires (!Meta.Util.is_wayland_compositor ())
    requires (window in panel_windows) {
        panel_windows[window].restore_previous_x11_region = true;
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
