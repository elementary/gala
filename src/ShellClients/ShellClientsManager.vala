/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Gala.ShellClientsManager : Object {
    private static ShellClientsManager instance;

    public static void init (WindowManager wm) {
        if (instance != null) {
            return;
        }

        instance = new ShellClientsManager (wm);
    }

    public static ShellClientsManager? get_instance () {
        return instance;
    }

    public WindowManager wm { get; construct; }

    private NotificationsClient notifications_client;
    private ManagedClient[] protocol_clients = {};

    private GLib.HashTable<Meta.Window, PanelWindow> windows = new GLib.HashTable<Meta.Window, PanelWindow> (null, null);
    private GLib.HashTable<Meta.Window, CenteredWindow> centered_windows = new GLib.HashTable<Meta.Window, CenteredWindow> (null, null);

    private BackgroundWindow[] background_windows;

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

        update_background_windows ();
        wm.get_display ().get_context ().get_backend ().get_monitor_manager ().monitors_changed.connect (update_background_windows);
    }

    private void update_background_windows () {
        var display = wm.get_display ();

        background_windows = new BackgroundWindow[display.get_n_monitors ()];
        for (int i = 0; i < background_windows.length; i++) {
            background_windows[i] = new BackgroundWindow (display, i);
        }
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
    }

    public void make_dock (Meta.Window window) {
        if (Meta.Util.is_wayland_compositor ()) {
            make_dock_wayland (window);
        } else {
            make_dock_x11 (window);
        }
    }

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

    public void set_anchor (Meta.Window window, Meta.Side side) {
        if (window in windows) {
            windows[window].update_anchor (side);
            return;
        }

        make_dock (window);
        // TODO: Return if requested by window that's not a trusted client?

        windows[window] = new PanelWindow (wm, window, side);

        // connect_after so we make sure the PanelWindow can destroy its barriers and struts
        window.unmanaging.connect_after (() => windows.remove (window));
    }

    /**
     * The size given here is only used for the hide mode. I.e. struts
     * and collision detection with other windows use this size. By default
     * or if set to -1 the size of the window is used.
     *
     * TODO: Maybe use for strut only?
     */
    public void set_size (Meta.Window window, int width, int height) {
        if (!(window in windows)) {
            warning ("Set anchor for window before size.");
            return;
        }

        windows[window].set_size (width, height);
    }

    public void set_hide_mode (Meta.Window window, Pantheon.Desktop.HideMode hide_mode) {
        if (!(window in windows)) {
            warning ("Set anchor for window before hide mode.");
            return;
        }

        windows[window].set_hide_mode (hide_mode);
    }

    public void make_centered (Meta.Window window) {
        if (window in centered_windows) {
            return;
        }

        centered_windows[window] = new CenteredWindow (wm, window);

        window.unmanaging.connect_after (() => centered_windows.remove (window));
    }

    public void make_background (Meta.Window window, int monitor_index) {
        if (monitor_index < 0 || monitor_index > background_windows.length) {
            warning ("Given monitor index out of bounds.");
            return;
        }

        foreach (var client in protocol_clients) {
            if (client.wayland_client.owns_window (window)) {
                client.wayland_client.make_desktop (window);
                break;
            }
        }

        background_windows[monitor_index].update_window (window);
    }

    /**
     * This clone will be valid until Meta.MonitorManager::monitors-changed was emitted.
     * After that the clone musn't be used. This will only return null if the monitor_index is out of bounds.
     */
    public Clutter.Actor? get_background_clone_for_monitor (int monitor_index) {
        if (monitor_index < 0 || monitor_index > background_windows.length) {
            warning ("Given monitor index out of bounds.");
            return null;
        }

        return background_windows[monitor_index].get_background_clone ();
    }

    public bool is_positioned_window (Meta.Window window) {
        bool positioned = (window in centered_windows) || (window in windows);
        window.foreach_ancestor ((ancestor) => {
            if (ancestor in centered_windows || ancestor in windows) {
                positioned = true;
            }

            return !positioned;
        });

        return positioned;
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
                    int parsed; // Will be used as Meta.Side which is a 4 value bitfield so check bounds for that
                    if (int.try_parse (val, out parsed) && 0 <= parsed && parsed <= 15) {
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

                case "centered":
                    make_centered (window);
                    break;

                default:
                    break;
            }
        }
    }
}
