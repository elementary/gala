/*
 * Copyright 2023-2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowStateSaver : GLib.Object {
    [DBus (name = "org.freedesktop.login1.Manager")]
    private interface LoginManager : Object {
        public signal void prepare_for_sleep (bool about_to_suspend);
    }

    private static unowned WindowTracker window_tracker;
    private static GLib.HashTable<string, GLib.Array<Meta.Window?>> app_windows;
    private static LoginManager? login_manager;
    private static Sqlite.Database db;

    public static void init (WindowTracker window_tracker) {
        WindowStateSaver.window_tracker = window_tracker;
        app_windows = new GLib.HashTable<string, GLib.Array<Meta.Window?>> (GLib.str_hash, GLib.str_equal);

        connect_to_logind.begin ();

        var dir = Path.build_filename (GLib.Environment.get_user_data_dir (), "io.elementary.gala");
        Posix.mkdir (dir, 0775);
        var path = Path.build_filename (dir, "windowstate.db");
        var rc = Sqlite.Database.open_v2 (path, out db);

        if (rc != Sqlite.OK) {
            critical ("Cannot open database: %d, %s", rc, db.errmsg ());
            return;
        }

        Sqlite.Statement stmt;
        rc = db.prepare_v2 (
            """
            CREATE TABLE IF NOT EXISTS apps (
                app_id       TEXT,
                window_index INTEGER,
                last_x       INTEGER,
                last_y       INTEGER,
                last_width   INTEGER,
                last_height  INTEGER,
                PRIMARY KEY (app_id, window_index)
            );
            """,
            -1, out stmt
        );

        if (rc == Sqlite.OK) {
            rc = stmt.step ();
            if (rc == Sqlite.DONE) {
                // disable synchronized commits for performance reasons
                rc = db.exec ("PRAGMA synchronous=OFF");
                if (rc != Sqlite.OK) {
                    warning ("Unable to disable synchronous mode %d, %s", rc, db.errmsg ());
                }

                return;
            }
        }

        critical ("Cannot create table 'apps': %d, %s", rc, db.errmsg ());
    }

    private async static void connect_to_logind () {
        try {
            login_manager = yield Bus.get_proxy (SYSTEM, "org.freedesktop.login1", "/org/freedesktop/login1");
            login_manager.prepare_for_sleep.connect ((about_to_suspend) => {
                if (about_to_suspend) {
                    save_all_windows_state ();
                }
            });
        } catch (Error e) {
            warning ("Unable to connect to logind bus: %s", e.message);
        }
    }

    public static void on_map (Meta.Window window) {
        var app_id = window_tracker.get_app_for_window (window).id;

        if (app_id.has_prefix ("window:")) {
            // if window failed to be identified, don't remember it
            return;
        }

        if (window.window_type != Meta.WindowType.NORMAL) {
            return;
        }

        if (ShellClientsManager.get_instance ().is_positioned_window (window)) {
            return;
        }

        if (!(app_id in app_windows)) {
            app_windows[app_id] = new GLib.Array<Meta.Window?> ();
        }

        var window_index = find_window_index (window, app_id);
        app_windows[app_id].insert_val (window_index, window);

        Sqlite.Statement stmt;
        const string SELECT_QUERY = "SELECT last_x, last_y, last_width, last_height FROM apps WHERE app_id = $app_id AND window_index = $window_index;";
        var rc = db.prepare_v2 (SELECT_QUERY, SELECT_QUERY.length, out stmt);
        stmt.bind_text (stmt.bind_parameter_index ("$app_id"), app_id);
        stmt.bind_int (stmt.bind_parameter_index ("$window_index"), window_index);
        if (rc != Sqlite.OK) {
            critical ("Cannot query app information from database: %d, %s", rc, db.errmsg ());
            return;
        }

        int cols = stmt.column_count ();
        if (stmt.step () == Sqlite.ROW) {
            int last_x = 0, last_y = 0, last_width = 0, last_height = 0;
            for (int i = 0; i < cols; i++) {
                if (stmt.column_name (i) == "last_x") {
                    last_x = stmt.column_int (i);
                }

                if (stmt.column_name (i) == "last_y") {
                    last_y = stmt.column_int (i);
                }

                if (stmt.column_name (i) == "last_width") {
                    last_width = stmt.column_int (i);
                }

                if (stmt.column_name (i) == "last_height") {
                    last_height = stmt.column_int (i);
                }
            }

            window.move_resize_frame (false, last_x, last_y, last_width, last_height);
            track_window (window, app_id);
            return;
        }

        var frame_rect = window.get_frame_rect ();

        const string INSERT_QUERY = "INSERT INTO apps (app_id, window_index, last_x, last_y, last_width, last_height) VALUES ($app_id, $window_index, $last_x, $last_y, $last_width, $last_height);";
        rc = db.prepare_v2 (INSERT_QUERY, INSERT_QUERY.length, out stmt);
        if (rc != Sqlite.OK) {
            critical ("Cannot insert app information into database: %d, %s", rc, db.errmsg ());
            return;
        }

        stmt.bind_text (stmt.bind_parameter_index ("$app_id"), app_id);
        stmt.bind_int (stmt.bind_parameter_index ("$window_index"), window_index);
        stmt.bind_int (stmt.bind_parameter_index ("$last_x"), frame_rect.x);
        stmt.bind_int (stmt.bind_parameter_index ("$last_y"), frame_rect.y);
        stmt.bind_int (stmt.bind_parameter_index ("$last_width"), frame_rect.width);
        stmt.bind_int (stmt.bind_parameter_index ("$last_height"), frame_rect.height);

        rc = stmt.step ();
        if (rc != Sqlite.DONE) {
            critical ("Cannot insert app information into database: %d, %s", rc, db.errmsg ());
            return;
        }

        track_window (window, app_id);
    }

    public static void on_shutdown () {
        save_all_windows_state ();
    }

    private static void track_window (Meta.Window window, string app_id) {
        window.unmanaging.connect (save_window_state);
    }

    private static void save_window_state (Meta.Window window) {
        var app_id = window_tracker.get_app_for_window (window).id;

        if (!(app_id in app_windows)) {
            critical ("Could not save window that is not mapped %s", app_id);
            return;
        }

        var window_index = find_window_index (window, app_id);
        if (window_index < app_windows[app_id].length) {
            app_windows[app_id].remove_index (window_index);
        }

        var value = null; // insert_val requires lvalue
        app_windows[app_id].insert_val (window_index, value);

        var frame_rect = window.get_frame_rect ();

        Sqlite.Statement stmt;
        const string UPDATE_QUERY = "UPDATE apps SET last_x = $last_x, last_y = $last_y, last_width = $last_width, last_height = $last_height WHERE app_id = $app_id AND window_index = $window_index;";
        var rc = db.prepare_v2 (UPDATE_QUERY, UPDATE_QUERY.length, out stmt);
        if (rc != Sqlite.OK) {
            critical ("Cannot update app position in database: %d, %s", rc, db.errmsg ());
            return;
        }

        stmt.bind_text (stmt.bind_parameter_index ("$app_id"), app_id);
        stmt.bind_int (stmt.bind_parameter_index ("$window_index"), window_index);
        stmt.bind_int (stmt.bind_parameter_index ("$last_x"), frame_rect.x);
        stmt.bind_int (stmt.bind_parameter_index ("$last_y"), frame_rect.y);
        stmt.bind_int (stmt.bind_parameter_index ("$last_width"), frame_rect.width);
        stmt.bind_int (stmt.bind_parameter_index ("$last_height"), frame_rect.height);

        rc = stmt.step ();
        if (rc != Sqlite.DONE) {
            critical ("Cannot update app position in database: %d, %s", rc, db.errmsg ());
            return;
        }
    }

    private static void save_all_windows_state () {
        foreach (unowned var windows in app_windows.get_values ()) {
            foreach (var window in windows) {
                save_window_state (window);
            }
        }
    }

    private static int find_window_index (Meta.Window window, string app_id) requires (app_id in app_windows) {
        unowned var windows_list = app_windows[app_id];
        var first_null = -1;
        for (int i = 0; i < windows_list.length; i++) {
            var w = windows_list.data[i];
            if (w == window) {
                return i;
            }

            if (w == null && first_null == -1) {
                first_null = i;
            }
        }

        if (first_null != -1) {
            return first_null;
        }

        return (int) windows_list.length;
    }
}
