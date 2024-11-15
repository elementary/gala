/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

class Gala.PinManager : GLib.Object {
    private static GLib.HashTable<Meta.Workspace, uint> pinned_workspace_indexes;
    private static Sqlite.Database db;

    public Meta.Display display { private get; construct; }

    private static PinManager? instance = null;
    public static void init (Meta.Display display) {
        if (instance != null) {
            warning ("PinManager.init: called init multiple times!");
            return;
        }

        instance = new PinManager (display);
    }

    public static PinManager get_default () {
        if (instance == null) {
            warning ("PinManager.get_default: init hasn't been called yet!");
        }

        return instance;
    }

    private PinManager (Meta.Display display) {
        Object (display: display);
    }

    construct {
        pinned_workspace_indexes = new GLib.HashTable<Meta.Workspace, uint> (null, null);

        var dir = Path.build_filename (GLib.Environment.get_user_data_dir (), "io.elementary.gala");
        Posix.mkdir (dir, 0775);
        var path = Path.build_filename (dir, "pinmanager.db");
        var rc = Sqlite.Database.open_v2 (path, out db);

        if (rc != Sqlite.OK) {
            critical ("Cannot open database: %d, %s", rc, db.errmsg ());
            return;
        }

        Sqlite.Statement stmt;
        rc = db.prepare_v2 (
            "CREATE TABLE IF NOT EXISTS pinned_workspaces (id INTEGER NOT NULL PRIMARY KEY);",
            -1, out stmt
        );

        if (rc != Sqlite.OK) {
            critical ("Cannot create table 'pinned_workspaces': %d, %s", rc, db.errmsg ());
            return;
        }

        rc = stmt.step ();

        if (rc != Sqlite.DONE) {
            critical ("Cannot create table 'pinned_workspaces': %d, %s", rc, db.errmsg ());
            return;
        }

        // disable synchronized commits for performance reasons
        rc = db.exec ("PRAGMA synchronous=OFF");
        if (rc != Sqlite.OK) {
            warning ("Unable to disable synchronous mode %d, %s", rc, db.errmsg ());
        }

        // load workspaces from db
        db.exec (
            "SELECT * FROM pinned_workspaces;",
            (n_columns, values, column_names) => {
                unowned var workspace_manager = display.get_workspace_manager ();

                var id = int.parse (values[0]);

                unowned Meta.Workspace workspace;
                if (id < workspace_manager.get_n_workspaces ()) {
                    workspace = workspace_manager.get_workspace_by_index (id);
                } else {
                    workspace = workspace_manager.append_new_workspace (false, display.get_current_time ());
                }

                track_pinned_workspace (workspace);

                return 0;
            }
        );

        unowned var workspace_manager = display.get_workspace_manager ();

        unowned Meta.Workspace workspace;
        if (workspace_manager.get_n_workspaces () == pinned_workspace_indexes.length) {
            // append an extra dynamic workspace
            workspace = workspace_manager.append_new_workspace (false, display.get_current_time ());
        } else {
            // assume the last workspace is dynamic
            workspace = workspace_manager.get_workspace_by_index (workspace_manager.get_n_workspaces () - 1);
        }

        track_dynamic_workspace (workspace);
    }

    private void add_dynamic_workspace () {
        unowned var workspace_manager = display.get_workspace_manager ();
        unowned var last_workspace = workspace_manager.get_workspace_by_index (workspace_manager.get_n_workspaces () - 1);

        if (!(last_workspace in pinned_workspace_indexes) && Utils.get_n_windows (last_workspace, true) == 0 == 0) {
            // last workspace is already dynamic and empty
            return;
        }

        unowned var new_workspace = workspace_manager.append_new_workspace (false, display.get_current_time ());
        track_dynamic_workspace (new_workspace);
    }

    private void track_dynamic_workspace (Meta.Workspace workspace) requires (workspace != null) {
        workspace.window_added.connect (on_window_added);
        workspace.window_removed.connect (on_window_removed);
    }

    private void untrack_dynamic_workspace (Meta.Workspace workspace) requires (workspace != null) {
        workspace.window_added.disconnect (on_window_added);
        workspace.window_removed.disconnect (on_window_removed);
    }

    private void on_window_added (Meta.Workspace workspace, Meta.Window window) {
        add_dynamic_workspace ();
    }

    private void on_window_removed (Meta.Workspace workspace, Meta.Window window) {
        if (workspace == null) {
            return;
        }

        if (Utils.get_n_windows (workspace, true) == 0) {
            warning ("trying to remove workspace %u", workspace.workspace_index);

            untrack_dynamic_workspace (workspace);

            unowned var workspace_manager = display.get_workspace_manager ();
            workspace_manager.remove_workspace (workspace, display.get_current_time ());
        }
    }

    /*
     * TODO: Write some documentation
     * TODO: Does it need to be public?
     */
    public bool is_workspace_pinned (Meta.Workspace workspace) {
        if (workspace == null) {
            critical ("PinManager.is_workspace_pinned: workspace is null!");
            return false;
        }

        return workspace in pinned_workspace_indexes;
    }

    /*
     * TODO: Write some documentation
     */
    public bool pin_workspace (Meta.Workspace workspace) {
        if (workspace == null) {
            critical ("PinManager.pin_workspace: workspace is null!");
            return false;
        }

        
        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "INSERT INTO pinned_workspaces (id) VALUES ('%u');"
            .printf (workspace.workspace_index),
            -1, out stmt
        );
        
        if (rc == Sqlite.OK) {
            rc = stmt.step ();
            if (rc == Sqlite.DONE) {
                untrack_dynamic_workspace (workspace);
                track_pinned_workspace (workspace);
                return true;
            }
        }

        critical ("Cannot insert workspace information into database: %d, %s", rc, db.errmsg ());
        return false;
    }

    /*
     * TODO: Write some documentation
     */
    public void unpin_workspace (Meta.Workspace workspace) {
        if (workspace == null) {
            critical ("PinManager.unpin_workspace: workspace is null!");
            return;
        }

        if (!is_workspace_pinned (workspace)) {
            warning ("PinManager.unpin_workspace: workspace is not pinned!");
            return;
        }

        
        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "DELETE FROM pinned_workspaces WHERE id = '%u';"
            .printf (workspace.workspace_index),
            -1, out stmt
        );
        
        track_dynamic_workspace (workspace);
        untrack_pinned_workspace (workspace);

        if (rc == Sqlite.OK) {
            rc = stmt.step ();
            if (rc == Sqlite.DONE) {
                return;
            }
        }

        critical ("Cannot delete workspace information from database: %d, %s", rc, db.errmsg ());
    }

    private void track_pinned_workspace (Meta.Workspace workspace) requires (workspace != null) {
        pinned_workspace_indexes[workspace] = workspace.workspace_index;
        workspace.notify["workspace-index"].connect (update_pinned_workspace_index);
    }

    private void untrack_pinned_workspace (Meta.Workspace workspace) requires (workspace != null) {
        pinned_workspace_indexes.remove (workspace);
        workspace.notify["workspace-index"].disconnect (update_pinned_workspace_index);
    }

    private void update_pinned_workspace_index (GLib.Object workspace_object, GLib.ParamSpec param_spec) {
        var workspace = (Meta.Workspace) workspace_object;

        Sqlite.Statement stmt;
        var rc = db.prepare_v2 (
            "UPDATE pinned_workspaces SET id = '%u' WHERE id = '%u';"
            .printf (pinned_workspace_indexes[workspace], workspace.workspace_index),
            -1, out stmt
        );

        pinned_workspace_indexes[workspace] = workspace.workspace_index;

        if (rc == Sqlite.OK) {
            rc = stmt.step ();
            if (rc == Sqlite.DONE) {
                return;
            }
        }

        critical ("Cannot update workspace index in database: %d, %s", rc, db.errmsg ());
    }
}
