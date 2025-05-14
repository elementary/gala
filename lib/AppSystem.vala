/*
 * Copyright 2021 elementary, Inc. <https://elementary.io>
 * Copyright 2021 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.AppSystem : GLib.Object {
    private static GLib.Once<AppSystem> instance;
    public static unowned AppSystem get_default () {
        return instance.once (() => new AppSystem ());
    }

    private GLib.HashTable<Gala.App, unowned Gala.App> running_apps;
    private GLib.HashTable<unowned string, Gala.App> id_to_app;
    private GLib.HashTable<string, string> startup_wm_class_to_id;
    private Gala.AppCache app_cache;
    private string[] all_desktop_files = {};
    private GLib.FileMonitor[]? directory_monitors;

    construct {
        id_to_app = new GLib.HashTable<unowned string, Gala.App> (str_hash, str_equal);
        startup_wm_class_to_id = new GLib.HashTable<string, string> (str_hash, str_equal);
        running_apps = new GLib.HashTable<Gala.App, unowned Gala.App> (null, null);
        app_cache = new AppCache ();

        update_desktop_files ();
    }

    private void update_desktop_files () {
        var data_dirs = Environment.get_system_data_dirs ();
        data_dirs += Environment.get_user_data_dir ();

        var create_monitors = directory_monitors == null;
        if (create_monitors) {
            directory_monitors = {};
        }

        foreach (unowned string data_dir in data_dirs) {
            var app_dir = Path.build_filename (data_dir, "applications");
            if (FileUtils.test (app_dir, FileTest.EXISTS)) {
                try {
                    foreach (var name in enumerate_children (app_dir)) {
                        if (!name.contains ("~") && name.has_suffix (".desktop")) {
                            all_desktop_files += name;
                        }
                    }

                    if (!create_monitors) {
                        continue;
                    }

                    var monitor = File.new_for_path (app_dir).monitor (GLib.FileMonitorFlags.NONE, null);
                    monitor.changed.connect ((file, other_file, event_type) => {
                        if (event_type == GLib.FileMonitorEvent.CHANGES_DONE_HINT) {
                            update_desktop_files ();
                        }
                    });
                    directory_monitors += monitor;
                } catch (Error e) {
                    debug ("Error inside %s: %s", app_dir, e.message);
                }
            }
        }
    }

    private string[] enumerate_children (string dir) throws Error {
        string[] result = {};
        FileInfo file_info;
        var enumerator = File.new_for_path (dir).enumerate_children (FileAttribute.STANDARD_NAME, 0);
        while ((file_info = enumerator.next_file ()) != null)
            result += file_info.get_name ();
        return result;
    }

    public unowned Gala.App? lookup_app (string id) {
        unowned Gala.App? app = id_to_app.lookup (id);
        if (app != null) {
            return app;
        }

        GLib.DesktopAppInfo? info = app_cache.lookup_id (id);
        if (info == null) {
            return null;
        }

        var owned_app = new Gala.App (info);
        app = owned_app;
        id_to_app.insert (owned_app.id, (owned) owned_app);
        return app;
    }

    public unowned Gala.App? lookup_startup_wmclass (string? wmclass) {
        if (wmclass == null) {
            return null;
        }

        GLib.DesktopAppInfo? info = app_cache.lookup_startup_wmclass (wmclass);
        if (info == null) {
            return null;
        }

        return lookup_app (info.get_id ());
    }

    private unowned Gala.App? lookup_heuristic_basename (string name) {
        /* Vendor prefixes are something that can be preprended to a .desktop
         * file name.
         */
        const string[] VENDOR_PREFIXES = {
            "gnome-",
            "fedora-",
            "mozilla-",
            "debian-",
        };

        unowned Gala.App? result = lookup_app (name);
        if (result != null) {
            return result;
        }

        foreach (unowned string prefix in VENDOR_PREFIXES) {
            result = lookup_app (prefix.concat (name));
            if (result != null) {
                return result;
            }
        }

        return null;
    }

    public unowned Gala.App? lookup_desktop_wmclass (string? wmclass) {
        if (wmclass == null) {
            return null;
        }

        /* First try without changing the case (this handles
        org.example.Foo.Bar.desktop applications)

        Note that is slightly wrong in that Gtk+ would set
        the WM_CLASS to Org.example.Foo.Bar, but it also
        sets the instance part to org.example.Foo.Bar, so we're ok
        */
        var desktop_file = wmclass.concat (".desktop");
        unowned Gala.App? app = lookup_heuristic_basename (desktop_file);
        if (app != null) {
            return app;
        }

        /* This handles "Fedora Eclipse", probably others.
         * Note _strdelimit is modify-in-place. */
        desktop_file._delimit (" ", '-');

        desktop_file = desktop_file.ascii_down ().concat (".desktop");

        return lookup_heuristic_basename (desktop_file);
    }

    public unowned Gala.App? guess_app_by_id (string _id) {
        var id = _id.ascii_down ();
        unowned Gala.App? result = null;

        foreach (var name in all_desktop_files) {
            // Try to find desktop file based on the application name
            if (name.contains (id) && (result = lookup_app (name)) != null) {
                return result;
            }
        }

        return null;
    }

    public void notify_app_state_changed (Gala.App app) {
        if (app.state == Gala.AppState.RUNNING) {
            running_apps.insert (app, app);
        } else if (app.state == Gala.AppState.STOPPED) {
            running_apps.remove (app);
        }
    }

    public GLib.List<unowned Gala.App> get_running_apps () {
        return running_apps.get_keys ();
    }
}
