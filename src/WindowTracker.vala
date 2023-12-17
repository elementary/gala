/*
 * Copyright 2021 elementary, Inc. <https://elementary.io>
 * Copyright 2021 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowTracker : GLib.Object {
    private GLib.HashTable<unowned Meta.Window, Gala.App> window_to_app;

    public signal void windows_changed ();

    construct {
        window_to_app = new GLib.HashTable<unowned Meta.Window, Gala.App> (direct_hash, direct_equal);
    }

    public void init (Meta.Display display) {
        unowned Meta.StartupNotification sn = display.get_startup_notification ();
        sn.changed.connect (on_startup_sequence_changed);
        load_initial_windows (display);
        init_window_tracking (display);
    }

    private void load_initial_windows (Meta.Display display) {
        GLib.List<weak Meta.Window> windows = display.list_all_windows ();
        foreach (weak Meta.Window window in windows) {
            track_window (window);
        }
    }

    private void init_window_tracking (Meta.Display display) {
        display.window_created.connect (track_window);
    }

    private void on_startup_sequence_changed (Meta.StartupSequence sequence) {
        unowned Gala.App? app = Gala.App.new_from_startup_sequence (sequence);
        if (app != null) {
            app.handle_startup_sequence (sequence);
        }
    }

    private static unowned Gala.App? get_app_from_id (string id) {
        var desktop_file = id.concat (".desktop");
        return Gala.AppSystem.get_default ().lookup_app (desktop_file);
    }

    private static unowned Gala.App? get_app_from_gapplication_id (Meta.Window window) {
        unowned string? id = window.get_gtk_application_id ();
        if (id == null) {
            return null;
        }

        return get_app_from_id (id);
    }

    private static unowned Gala.App? get_app_from_pid (Posix.pid_t pid) {
        var running_apps = Gala.AppSystem.get_default ().get_running_apps ();
        foreach (unowned Gala.App app in running_apps) {
            var app_pids = app.get_pids ();
            foreach (var app_pid in app_pids) {
                if (app_pid == pid) {
                    return app;
                }
            }
        }

        return null;
    }

    private unowned Gala.App? get_app_from_window_pid (Meta.Window window) {
        if (window.is_remote ()) {
            return null;
        }

        var pid = window.get_pid ();
        if (pid < 1) {
            return null;
        }

        return get_app_from_pid (pid);
    }

    private static bool check_app_id_prefix (Gala.App app, string? prefix) {
        if (prefix == null) {
            return true;
        }

        return app.id.has_prefix (prefix);
    }

    private unowned Gala.App? get_app_from_window_wmclass (Meta.Window window) {
        string? app_prefix = null;
        unowned string? sandbox_id = window.get_sandboxed_app_id ();
        if (sandbox_id != null) {
            app_prefix = "%s.".printf (sandbox_id);
        }

        /* Notes on the heuristics used here:
        much of the complexity here comes from the desire to support
        Chrome apps.

        From https://bugzilla.gnome.org/show_bug.cgi?id=673657#c13

        Currently chrome sets WM_CLASS as follows (the first string is the 'instance',
        the second one is the 'class':

        For the normal browser:
        WM_CLASS(STRING) = "chromium", "Chromium"

        For a bookmarked page (through 'Tools -> Create application shortcuts')
        WM_CLASS(STRING) = "wiki.gnome.org__GnomeShell_ApplicationBased", "Chromium"

        For an application from the chrome store (with a .desktop file created through
        right click, "Create shortcuts" from Chrome's apps overview)
        WM_CLASS(STRING) = "crx_blpcfgokakmgnkcojhhkbfbldkacnbeo", "Chromium"

        The .desktop file has a matching StartupWMClass, but the name differs, e.g. for
        the store app (youtube) there is

        .local/share/applications/chrome-blpcfgokakmgnkcojhhkbfbldkacnbeo-Default.desktop

        with

        StartupWMClass=crx_blpcfgokakmgnkcojhhkbfbldkacnbeo

        Note that chromium (but not google-chrome!) includes a StartupWMClass=chromium
        in their .desktop file, so we must match the instance first.

        Also note that in the good case (regular gtk+ app without hacks), instance and
        class are the same except for case and there is no StartupWMClass at all.
        */

        /* first try a match from WM_CLASS (instance part) to StartupWMClass */
        unowned string wm_instance = window.get_wm_class_instance ();
        unowned var appsys = Gala.AppSystem.get_default ();

        unowned Gala.App? app = appsys.lookup_startup_wmclass (wm_instance);
        if (app != null && check_app_id_prefix (app, app_prefix)) {
            return app;
        }

        /* then try a match from WM_CLASS to StartupWMClass */
        unowned string wm_class = window.get_wm_class ();
        app = appsys.lookup_startup_wmclass (wm_class);
        if (app != null && check_app_id_prefix (app, app_prefix)) {
            return app;
        }

        /* then try a match from WM_CLASS (instance part) to .desktop */
        app = appsys.lookup_desktop_wmclass (wm_instance);
        if (app != null && check_app_id_prefix (app, app_prefix)) {
            return app;
        }

        /* finally, try a match from WM_CLASS to .desktop */
        app = appsys.lookup_desktop_wmclass (wm_class);
        if (app != null && check_app_id_prefix (app, app_prefix)) {
            return app;
        }

        return null;
    }

    private unowned Gala.App? get_app_from_sandboxed_app_id (Meta.Window window) {
        unowned string? id = window.get_sandboxed_app_id ();
        if (id == null) {
            return null;
        }

        return get_app_from_id (id);
    }

    private unowned Gala.App? get_app_from_window_group (Meta.Window window) {
        unowned Meta.Group? group = window.get_group ();
        if (group == null) {
            return null;
        }

        GLib.SList<weak Meta.Window> group_windows = group.list_windows ();
        foreach (weak Meta.Window group_window in group_windows) {
            if (group_window.window_type != Meta.WindowType.NORMAL) {
                continue;
            }

            unowned Gala.App? result = window_to_app.lookup (group_window);
            if (result != null) {
                return result;
            }
        }

        return null;
    }

    public Gala.App get_app_for_window (Meta.Window window) {
        unowned Meta.Window? transient_for = window.get_transient_for ();
        if (transient_for != null) {
            return get_app_for_window (transient_for);
        }

        /* First, we check whether we already know about this window,
        * if so, just return that.
        */
        unowned Gala.App? result;
        if (window.window_type == Meta.WindowType.NORMAL || window.is_remote ()) {
            result = window_to_app.lookup (window);
            if (result != null) {
                return result;
            }
        }

        if (window.is_remote ()) {
            return new Gala.App.for_window (window);
        }

        /* Check if the app's WM_CLASS specifies an app; this is
        * canonical if it does.
        */

        result = get_app_from_window_wmclass (window);
        if (result != null) {
            return result;
        }

        /* Check if the window was opened from within a sandbox; if this
        * is the case, a corresponding .desktop file is guaranteed to match;
        */
        result = get_app_from_sandboxed_app_id (window);
        if (result != null) {
            return result;
        }

        /* Check if the window has a GApplication ID attached; this is
        * canonical if it does
        */
        result = get_app_from_gapplication_id (window);
        if (result != null) {
            return result;
        }

        result = get_app_from_window_pid (window);
        if (result != null) {
            return result;
        }

        /* Now we check whether we have a match through startup-notification */
        unowned string? startup_id = window.get_startup_id ();
        if (startup_id != null) {
            unowned Meta.StartupNotification sn = window.get_display ().get_startup_notification ();
            unowned GLib.SList<Meta.StartupSequence> sequences = sn.get_sequences ();
            foreach (unowned var sequence in sequences) {
                unowned string id = sequence.get_id ();
                if (id != startup_id) {
                    continue;
                }

                unowned string? appid = sequence.get_application_id ();
                if (appid != null) {
                    result = AppSystem.get_default ().lookup_app (GLib.Path.get_basename (appid));
                    if (result != null) {
                        return result;
                    }
                }
            }
        }

        /* If we didn't get a startup-notification match, see if we matched
        * any other windows in the group.
        */
        result = get_app_from_window_group (window);
        if (result != null) {
            return result;
        }

        /* Our last resort - we create a fake app from the window */
        return new Gala.App.for_window (window);

    }

    private void tracked_window_changed (Meta.Window window) {
        /* It's simplest to just treat this as a remove + add. */
        disassociate_window (window);
        track_window (window);
    }

    private void tracked_window_notified (GLib.Object object, GLib.ParamSpec pspec) {
        tracked_window_changed ((Meta.Window) object);
    }

    private void track_window (Meta.Window window) {
        var app = get_app_for_window (window);
        if (app == null) {
            return;
        }

        window_to_app.insert (window, app);

        window.notify["wm-class"].connect (tracked_window_notified);
        window.notify["gtk-application-id"].connect (tracked_window_notified);
        window.unmanaged.connect (disassociate_window);

        app.add_window (window);

        windows_changed ();
    }

    private void disassociate_window (Meta.Window window) {
        var app = get_app_for_window (window);
        if (app == null) {
            return;
        }

        window.unmanaged.disconnect (disassociate_window);
        window.notify["wm-class"].disconnect (tracked_window_notified);
        window.notify["gtk-application-id"].disconnect (tracked_window_notified);
        app.remove_window (window);
        window_to_app.remove (window);

        windows_changed ();
    }
}
