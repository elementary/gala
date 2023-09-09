/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowStateSaver : GLib.Object {
    private static unowned WindowTracker window_tracker;
    private static GLib.GenericSet<string> opened_app_ids;
    private static Sqlite.Database db;

    public static void init (WindowTracker window_tracker) {
        WindowStateSaver.window_tracker = window_tracker;
        opened_app_ids = new GLib.GenericSet<string> (GLib.str_hash, GLib.str_equal);

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
                    warning ("Unable to disable synchronous mode %d, %s\n", rc, db.errmsg ());
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

        if (app_id in opened_app_ids) {
            // If an app has two windows track only the primary window
            return;
        }

        db.exec ("SELECT last_x, last_y FROM apps WHERE id = '%s';".printf (app_id), (n_columns, values, column_names) => {
            window.move_frame (false, int.parse (values[0]), int.parse (values[1]));
            track_window (window, app_id);

            return 0;
        });

        if (app_id in opened_app_ids) {
            // App was added in callback
            return;
        }

        unowned var actor = (Meta.WindowActor) window.get_compositor_private ();

        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "INSERT INTO apps (id, last_x, last_y) VALUES ('%s', '%f', '%f');".printf (app_id, (int) actor.x, (int) actor.y),
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
        window.position_changed.connect (on_window_position_changed);

        opened_app_ids.add (app_id);
        window.unmanaged.connect (() => {
            opened_app_ids.remove (app_id);
        });
    }


    private static void on_window_position_changed (Meta.Window window) {
        // TODO: throttle writing to db

        var app_id = window_tracker.get_app_for_window (window).id;

        unowned var actor = (Meta.WindowActor) window.get_compositor_private ();

        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "UPDATE apps SET last_x = '%d', last_y = '%d' WHERE id = '%s';".printf ((int) actor.x, (int) actor.y, app_id),
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
