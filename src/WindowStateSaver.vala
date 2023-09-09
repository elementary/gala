/*
 * Copyright 2021 elementary, Inc. <https://elementary.io>
 * Copyright 2021 Corentin Noël <tintou@noel.tf>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.WindowStateSaver : GLib.Object {
    private static WindowManager wm;
    private static GLib.GenericSet<string> opened_app_ids;
    private static Sqlite.Database db;

    public static void init (WindowManager wm) {
        WindowStateSaver.wm = wm;
        opened_app_ids = new GLib.GenericSet<string> (GLib.str_hash, GLib.str_equal);

        var path = Path.build_filename (Environment.get_home_dir (), ".local", "share", "io.elementary.gala-windowstate.db");

        var rc = Sqlite.Database.open_v2 (path, out db);

        if (rc != Sqlite.OK) {
            critical ("Cannot open database: %d, %s", rc, db.errmsg ());
            return;
        }

        Sqlite.Statement stmt;
        rc = db.prepare_v2 (
            "CREATE TABLE IF NOT EXISTS apps ("
            + "id TEXT PRIMARY KEY, "
            + "last_x INTEGER, "
            + "last_y INTEGER)",
            -1,
            out stmt
        );

        if (rc != Sqlite.OK) {
            critical ("Cannot create table 'apps': %d, %s", rc, db.errmsg ());
            return;
        }

        rc = stmt.step ();

        if (rc != Sqlite.DONE) {
            critical ("Cannot create table 'apps': %d, %s", rc, db.errmsg ());
            return;
        }

        // disable synchronized commits for performance reasons
        rc = db.exec ("PRAGMA synchronous=OFF");

        if (rc != Sqlite.OK) {
            warning ("Unable to disable synchronous mode %d, %s\n", rc, db.errmsg ());
        }

        wm.get_display ().window_created.connect (on_window_created);

        warning ("Initialized WindowStateSaver");
    }

    private static void on_window_created (Meta.Window window) {
        unowned var window_tracker = ((WindowManagerGala) wm).window_tracker;
        var app = window_tracker.get_app_for_window (window);
        var app_id = app.id;

        warning ("on_window_created");

        if (window.window_type != Meta.WindowType.NORMAL) {
            warning ("Window of incorrect type");
            return;
        }

        if (app_id in opened_app_ids) {
            warning ("App already has opened window");
            // If an app has two windows, listen only to the primary window
            return;
        }

        if (window.find_root_ancestor () != window) {
            warning ("Window has ancestor");
            // If window has ancestor, don't listen to its' changes
            return;
        }

        db.exec ("SELECT last_x, last_y FROM apps WHERE id = '%s';".printf (app_id), (n_columns, values, column_names) => {
            if (values.length != 0) {
                window.move_frame (false, int.parse (values[0]), int.parse (values[1]));
            }


            track_window (window, app_id);
            return 0;
        });

        if (app_id in opened_app_ids) {
            // App was added in callback
            return;
        }

        warning ("Values length is 0, window was not saved to db... I guess?");

        unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
        
        var app_last_x = (int) actor.x;
        var app_last_y = (int) actor.y;

        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "INSERT INTO apps (id, last_x, last_y) VALUES ('%s', '%f', '%f');".printf (app_id, app_last_x, app_last_y),
            -1,
            out stmt
        );

        if (rc != Sqlite.OK) {
            critical ("Cannot insert app information into database: %d, %s", rc, db.errmsg ());
            return;
        }

        rc = stmt.step ();

        if (rc != Sqlite.DONE) {
            critical ("Cannot insert app information into database: %d, %s", rc, db.errmsg ());
            return;
        }

        warning ("Added app to db %s %f %f", app_id, app_last_x, app_last_y);

        track_window (window, app_id);
    }

    private static void track_window (Meta.Window window, string app_id) {
        window.position_changed.connect (on_window_position_changed);

        opened_app_ids.add (app_id);
        window.unmanaged.connect (() => {
            opened_app_ids.remove (app_id);
        });
    }

    private static void on_window_position_changed (Meta.Window window) {
        unowned var window_tracker = ((WindowManagerGala) wm).window_tracker;
        var app = window_tracker.get_app_for_window (window);

        unowned var actor = (Meta.WindowActor) window.get_compositor_private ();
        
        var app_id = app.id;
        var app_last_x = (int) actor.x;
        var app_last_y = (int) actor.y;

        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "UPDATE apps SET last_x = '%d', last_y = '%d' WHERE id = '%s';".printf (app_last_x, app_last_y, app_id),
            -1,
            out stmt
        );

        if (rc != Sqlite.OK) {
            critical ("Cannot update app position in database: %d, %s", rc, db.errmsg ());
            return;
        }

        rc = stmt.step ();

        if (rc != Sqlite.DONE) {
            critical ("Cannot update app position in databasee: %d, %s", rc, db.errmsg ());
            return;
        }

        warning ("Updated app in db %s %f %f", app_id, app_last_x, app_last_y);
    }
}
