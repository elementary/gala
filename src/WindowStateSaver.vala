/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowStateSaver : GLib.Object {
    private static unowned WindowTracker window_tracker;
    private static Sqlite.Database db;

    public static void init (WindowTracker window_tracker) {
        WindowStateSaver.window_tracker = window_tracker;

        var path = Path.build_filename (Environment.get_home_dir (), ".local", "share", "io.elementary.gala-windowstate.db");
        var rc = Sqlite.Database.open_v2 (path, out db);

        if (rc != Sqlite.OK) {
            critical ("Cannot open database: %d, %s", rc, db.errmsg ());
            return;
        }

        Sqlite.Statement stmt;
        rc = db.prepare_v2 (
            """
            CREATE TABLE IF NOT EXISTS apps (
                id TEXT PRIMARY KEY,
                last_x INTEGER,
                last_y INTEGER
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
        var app_id = window_tracker.get_app_for_window (window).id;

        if (app_id.has_prefix ("window:")) {
            // if window failed to be identified, don't remember it
            return;
        }

        if (window.window_type != Meta.WindowType.NORMAL) {
            return;
        }

        db.exec ("SELECT last_x, last_y FROM apps WHERE id = '%s';".printf (window.get_id ().to_string ()), (n_columns, values, column_names) => {
            window.move_frame (false, int.parse (values[0]), int.parse (values[1]));
            track_window (window, app_id);

            return 0;
        });

        var frame_rect = window.get_frame_rect ();

        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "INSERT INTO apps (id, last_x, last_y) VALUES ('%s', '%d', '%d');".printf (window.get_id ().to_string (), frame_rect.x, frame_rect.y),
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
        var app = window_tracker.get_app_for_window (window);


        foreach (var opened_window in app.get_windows ()) {
            if (opened_window == window) {
                continue;
            }

            if (opened_window.window_type != Meta.WindowType.NORMAL) {
                continue;
            }

            track_window (opened_window, app.id);
            break;
        }

        var frame_rect = window.get_frame_rect ();

        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "UPDATE apps SET last_x = '%d', last_y = '%d' WHERE id = '%s';".printf (frame_rect.x, frame_rect.y, window.get_id ().to_string ()),
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
}
