/*
 * Copyright 2021 elementary, Inc. <https://elementary.io>
 * Copyright 2021 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public enum Gala.AppState {
    STOPPED,
    STARTING,
    RUNNING
}

public class Gala.App : GLib.Object {
    public string id {
        get {
            if (app_info != null) {
                return app_info.get_id ();
            } else {
                return window_id_string;
            }
        }
    }

    public GLib.DesktopAppInfo? app_info { get; construct; }

    public GLib.Icon icon {
        get {
            if (app_info != null) {
                return app_info.get_icon ();
            }

            if (fallback_icon == null) {
                fallback_icon = new GLib.ThemedIcon ("application-x-executable");
            }

            return fallback_icon;
        }
    }

    public string name {
        get {
            if (app_info != null) {
                return app_info.get_name ();
            } else {
                unowned string? name = null;
                var window = get_backing_window ();
                if (window != null) {
                    name = window.get_wm_class ();
                }

                return name ?? C_("program", "Unknown");
            }
        }
    }

    public string? description {
        get {
            if (app_info != null) {
                return app_info.get_description ();
            }

            return null;
        }
    }

    public Gala.AppState state { get; private set; default = AppState.STOPPED; }

    private GLib.SList<Meta.Window> windows = new GLib.SList<Meta.Window> ();
    private uint interesting_windows = 0;
    private string? window_id_string = null;
    private GLib.Icon? fallback_icon = null;
    private int started_on_workspace;

    public static unowned App? new_from_startup_sequence (Meta.StartupSequence sequence) {
        unowned string? app_id = sequence.get_application_id ();
        if (app_id == null) {
            return null;
        }

        var basename = GLib.Path.get_basename (app_id);
        unowned var appsys = Gala.AppSystem.get_default ();
        return appsys.lookup_app (basename);
    }

    public App (GLib.DesktopAppInfo info) {
        Object (app_info: info);
    }

    public App.for_window (Meta.Window window) {
        window_id_string = "window:%u".printf (window.get_stable_sequence ());
        add_window (window);
    }

    public unowned GLib.SList<Meta.Window> get_windows () {
        return windows;
    }

    public void add_window (Meta.Window window) {
        if (windows.find (window) != null) {
            return;
        }

        windows.prepend (window);
        if (!window.is_skip_taskbar ()) {
            interesting_windows++;
        }

        sync_running_state ();
    }


    public void remove_window (Meta.Window window) {
        if (windows.find (window) == null) {
            return;
        }

        if (!window.is_skip_taskbar ()) {
            interesting_windows--;
        }

        windows.remove (window);
        sync_running_state ();
    }

    private void sync_running_state () {
        if (state != Gala.AppState.STARTING) {
            unowned var app_sys = Gala.AppSystem.get_default ();
            if (interesting_windows == 0) {
                state = Gala.AppState.STOPPED;
                app_sys.notify_app_state_changed (this);
            } else {
                state = Gala.AppState.RUNNING;
                app_sys.notify_app_state_changed (this);
            }
        }
    }

    public void handle_startup_sequence (Meta.StartupSequence sequence) {
        bool starting = !sequence.get_completed ();

        if (starting && state == AppState.STOPPED) {
            state = AppState.STARTING;
        }

        if (starting) {
            started_on_workspace = sequence.workspace;
        } else if (interesting_windows > 0) {
            state = AppState.RUNNING;
        } else {
            state = AppState.STOPPED;
        }

        unowned var app_sys = Gala.AppSystem.get_default ();
        app_sys.notify_app_state_changed (this);
    }

    private Meta.Window? get_backing_window () requires (app_info == null) {
        return windows.data;
    }

    public GLib.SList<Posix.pid_t?> get_pids () {
        var results = new GLib.SList<Posix.pid_t?> ();
        foreach (unowned var window in windows) {
            var pid = window.get_pid ();
            if (pid < 1) {
                continue;
            }

            /* Note in the (by far) common case, app will only have one pid, so
             * we'll hit the first element, so don't worry about O(N^2) here.
             */
            if (results.find (pid) == null) {
                results.prepend (pid);
            }
        }

        return results;
    }
}
