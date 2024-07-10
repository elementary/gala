/*
 * Copyright 2022 elementary, Inc. <https://elementary.io>
 * Copyright 2022 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[DBus (name="org.pantheon.gala.DesktopIntegration")]
public class Gala.DesktopIntegration : GLib.Object {
    public struct RunningApplication {
        string app_id;
        GLib.HashTable<unowned string, Variant> details;
    }

    public struct Window {
        uint64 uid;
        GLib.HashTable<unowned string, Variant> properties;
    }

    private unowned WindowManagerGala wm;
    public uint version { get; default = 1; }
    public signal void running_applications_changed ();
    public signal void windows_changed ();

    public DesktopIntegration (WindowManagerGala wm) {
        this.wm = wm;
        wm.window_tracker.windows_changed.connect (() => windows_changed ());
    }

    public RunningApplication[] get_running_applications () throws GLib.DBusError, GLib.IOError {
        RunningApplication[] returned_apps = {};
        var apps = Gala.AppSystem.get_default ().get_running_apps ();
        foreach (unowned var app in apps) {
            returned_apps += RunningApplication () {
                app_id = app.id,
                details = new GLib.HashTable<unowned string, Variant> (str_hash, str_equal)
            };
        }

        return (owned) returned_apps;
    }

    private bool is_eligible_window (Meta.Window window) {
        if (window.is_override_redirect ()) {
            return false;
        }

        switch (window.get_window_type ()) {
            case Meta.WindowType.NORMAL:
            case Meta.WindowType.DIALOG:
            case Meta.WindowType.MODAL_DIALOG:
            case Meta.WindowType.UTILITY:
                return true;
            default:
                return false;
        }
    }

    public Window[] get_windows () throws GLib.DBusError, GLib.IOError {
        Window[] returned_windows = {};
        var apps = Gala.AppSystem.get_default ().get_running_apps ();
        var active_workspace = wm.get_display ().get_workspace_manager ().get_active_workspace ();
        foreach (unowned var app in apps) {
            foreach (weak Meta.Window window in app.get_windows ()) {
                if (!is_eligible_window (window)) {
                    continue;
                }

                var properties = new GLib.HashTable<unowned string, Variant> (str_hash, str_equal);
                var frame_rect = window.get_frame_rect ();
                unowned var title = window.get_title ();
                unowned var wm_class = window.get_wm_class ();
                unowned var sandboxed_app_id = window.get_sandboxed_app_id ();

                properties.insert ("app-id", new GLib.Variant.string (app.id));
                properties.insert ("client-type", new GLib.Variant.uint32 (window.get_client_type ()));
                properties.insert ("is-hidden", new GLib.Variant.boolean (window.is_hidden ()));
                properties.insert ("has-focus", new GLib.Variant.boolean (window.has_focus ()));
                properties.insert ("on-active-workspace", new GLib.Variant.boolean (window.located_on_workspace (active_workspace)));
                properties.insert ("width", new GLib.Variant.uint32 (frame_rect.width));
                properties.insert ("height", new GLib.Variant.uint32 (frame_rect.height));

                // These properties may not be available for all windows:
                if (title != null) {
                    properties.insert ("title", new GLib.Variant.string (title));
                }

                if (wm_class != null) {
                    properties.insert ("wm-class", new GLib.Variant.string (wm_class));
                }

                if (sandboxed_app_id != null) {
                    properties.insert ("sandboxed-app-id", new GLib.Variant.string (sandboxed_app_id));
                }

                returned_windows += Window () {
                    uid = window.get_id (),
                    properties = properties
                };
            }
        }

        return (owned) returned_windows;
    }

    public void focus_window (uint64 uid) throws GLib.DBusError, GLib.IOError {
        var apps = Gala.AppSystem.get_default ().get_running_apps ();
        foreach (unowned var app in apps) {
            foreach (weak Meta.Window window in app.get_windows ()) {
                if (window.get_id () == uid) {
                    window.get_workspace ().activate_with_focus (window, wm.get_display ().get_current_time ());
                }
            }
        }
    }

    public void show_windows_for (string app_id) throws IOError, DBusError {
        if (wm.window_overview == null) {
            throw new IOError.FAILED ("Window overview not provided by window manager");
        }

        App app;
        if ((app = AppSystem.get_default ().lookup_app (app_id)) == null) {
            throw new IOError.NOT_FOUND ("App not found");
        }

        uint64[] window_ids = {};
        foreach (var window in app.get_windows ()) {
            window_ids += window.get_id ();
        }

        var hints = new HashTable<string, Variant> (str_hash, str_equal);
        hints["windows"] = window_ids;

        if (wm.window_overview.is_opened ()) {
            wm.window_overview.close ();
        }

        wm.window_overview.open (hints);
    }
}
