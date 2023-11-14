/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowStateSaver : GLib.Object {
    private static unowned WindowTracker window_tracker;
    private static GLib.HashTable<string, GLib.Array<Meta.Window?>> app_windows;
    private static Sqlite.Database db;

    public static void init (WindowTracker window_tracker) {
        WindowStateSaver.window_tracker = window_tracker;
        app_windows = new GLib.HashTable<string, GLib.Array<Meta.Window?>> (GLib.str_hash, GLib.str_equal);

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

    public static void on_map (Meta.Window window) {
        var app_id = GLib.Markup.escape_text (window_tracker.get_app_for_window (window).id);

        if (app_id.has_prefix ("window:")) {
            // if window failed to be identified, don't remember it
            return;
        }

        if (window.window_type != Meta.WindowType.NORMAL) {
            return;
        }

        if (!(app_id in app_windows)) {
            app_windows[app_id] = new GLib.Array<Meta.Window?> ();
        }

        var window_index = find_window_index (window, app_id);
        app_windows[app_id].insert_val (window_index, window);

        var tracking_window = false;
        db.exec (
            "SELECT last_x, last_y, last_width, last_height FROM apps WHERE app_id = '%s' AND window_index = '%d';".printf (app_id, window_index),
            (n_columns, values, column_names) => {
                window.move_resize_frame (false, int.parse (values[0]), int.parse (values[1]), int.parse (values[2]), int.parse (values[3]));
                track_window (window, app_id);
                tracking_window = true;

                return 0;
            }
        );

        if (tracking_window) {
            // App was added in callback
            return;
        }

        var frame_rect = window.get_frame_rect ();

        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "INSERT INTO apps (app_id, window_index, last_x, last_y, last_width, last_height) VALUES ('%s', '%d', '%d', '%d', '%d', '%d');"
            .printf (app_id, window_index, frame_rect.x, frame_rect.y, frame_rect.width, frame_rect.height),
            -1, out stmt
        );

        if (rc == Sqlite.OK) {
            rc = stmt.step ();
            if (rc == Sqlite.DONE) {
                track_window (window, app_id);
                return;
            }
        }

        critical ("Cannot insert app information into database: %d, %s", rc, db.errmsg ());
    }

    private static void track_window (Meta.Window window, string app_id) {
        window.unmanaging.connect (on_window_unmanaging);
    }

    private static void on_window_unmanaging (Meta.Window window) {
        var app_id = GLib.Markup.escape_text (window_tracker.get_app_for_window (window).id);

        var window_index = find_window_index (window, app_id);
        app_windows[app_id].remove_index (window_index);
        var value = null; // insert_val requires lvalue
        app_windows[app_id].insert_val (window_index, value);

        var frame_rect = window.get_frame_rect ();

        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "UPDATE apps SET last_x = '%d', last_y = '%d', last_width = '%d', last_height = '%d' WHERE app_id = '%s' AND window_index = '%d';"
            .printf (frame_rect.x, frame_rect.y, frame_rect.width, frame_rect.height, app_id, window_index),
            -1, out stmt
        );

        if (rc == Sqlite.OK) {
            rc = stmt.step ();
            if (rc == Sqlite.DONE) {
                return;
            }
        }

        critical ("Cannot update app position in database: %d, %s", rc, db.errmsg ());
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
