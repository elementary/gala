
using Meta;
namespace Gala
{ 
    public class WorkspaceWindowRestore : Object 
    { 
        const int[] RELEVANCE_TABLE = { 10, 6, 4, 2, 1 };
        const int TARGET_REVELANCE = 16;
        const int GET_APP_ID_TIMEOUT = 100;

        class WorkspaceConfig : Gee.ArrayList<string> {}
        class LogicalConfig : Gee.ArrayList<WorkspaceConfig> {}

        struct WorkspaceScore {
            unowned Meta.Workspace ws;
            int left;
            int right;
            int target;
        }

        struct WorkspaceSolution {
            int score;
            bool add;
        }

        public unowned WindowManager wm { get; construct; }

        signal void matcher_updated ();

        Gee.HashMap<int, Meta.Workspace> bindings;
        Gee.HashMap<Window, string> app_ids_cache;
        Gee.HashMap<string, GLib.Settings> app_settings_cache;
        SettingsSchema schema;

        static VariantType string_matrix_type;
        static Bamf.Matcher matcher;
        static construct
        {
            matcher = Bamf.Matcher.get_default ();
            string_matrix_type = new VariantType ("aas");
        }

        static WorkspaceWindowRestore? instance = null;
        public static unowned WorkspaceWindowRestore? get_default ()
        {
            return instance;
        }

        public static void init (WindowManager wm)
        {
            instance = new WorkspaceWindowRestore (wm);
        }

        construct
        {
            bindings = new Gee.HashMap<int, Meta.Workspace> ();
            app_ids_cache = new Gee.HashMap<Window, string> ();
            app_settings_cache = new Gee.HashMap<string, GLib.Settings> ();
            matcher.view_opened.connect ((view) => matcher_updated ());

            schema = SettingsSchemaSource.get_default ().lookup ("org.pantheon.desktop.gala.behavior.application", true);
        }

        WorkspaceWindowRestore (WindowManager wm)
        {
            Object (wm: wm);
        }

        public async void register_all ()
        {
            unowned Screen screen = wm.get_screen ();
            foreach (Workspace ws in screen.get_workspaces ()) {
                foreach (unowned Window window in ws.list_windows ()) {
                    if (window.get_window_type () != NORMAL) {
                        continue;
                    }

                    yield register_window (window);
                }
            }
        }

        public void update_workspace_reordered (int old_index, int new_index)
        {
            save_window_config (null);
        }

        public void update_window_move_to_workspace (Window window, int old_index, int new_index)
        {
            save_window_config (null);

        }

        public async void update_window_move_to_new_workspace (Window window, int old_index, int new_index)
        {
            save_window_config (null);
        }

        public async void register_window (Window window)
        {
            if (!yield restore_window_config (window)) {
                yield save_window_config (window);
            }
        }

        public void deregister_window (Window window)
        {
            //  window.workspace_changed.disconnect (on_window_workspace_changed);

            // We will explicitly get the workspace index now in sync because
            // the workspace may not exist anymore when doing this asynchronously
            //  save_window_config.begin (window, window.get_workspace ().index ());
        }

        //  void on_window_workspace_changed (Window window)
        //  {
        //      save_window_config.begin (window);
        //  }

        GLib.Settings get_settings_for_id (string id)
        {
            var app_settings = app_settings_cache[id];
            if (app_settings == null) {
                app_settings = new GLib.Settings.full (schema, null, "/org/pantheon/desktop/gala/behavior/applications/%s/".printf (id));
                app_settings.delay ();
                app_settings_cache[id] = app_settings;
            }

            return app_settings;
        }

        public async void save_window_config (Window? __window, int workspace_index = -1)
        {
            foreach (Workspace workspace in wm.get_screen ().get_workspaces ()) {
                foreach (unowned Window window in workspace.list_windows ()) {
                    if (window.get_window_type () != NORMAL) {
                        continue;
                    }

                    string? id = yield wait_for_app_id (window);
                    if (id == null) {
                        continue;
                    }

                    var app_settings = get_settings_for_id (id);
                    yield save_app_settings (app_settings, workspace, id);
                }
            }
        }

        async void save_app_settings (GLib.Settings app_settings, Workspace target, string target_id)
        {
            int index = target.index ();
            unowned Screen screen = wm.get_screen ();

            int n_workspaces = screen.get_n_workspaces ();

            var left_config = new LogicalConfig ();
            if (index > 0) {
                for (int left_index = index - 1; left_index >= 0; left_index--) {
                    unowned Workspace ws = screen.get_workspace_by_index (left_index);
                    var ws_config = yield create_config_from_workspace (ws);
                    if (ws_config.size > 0) {
                        left_config.add (ws_config);
                    }
                }
            }

            app_settings.set_value ("left-config", logical_config_to_variant (left_config, target_id));

            var right_config = new LogicalConfig ();
            if (index < n_workspaces - 1) {
                for (int right_index = index + 1; right_index < n_workspaces; right_index++) {
                    unowned Workspace ws = screen.get_workspace_by_index (right_index);
                    var ws_config = yield create_config_from_workspace (ws);
                    if (ws_config.size > 0) {
                        right_config.add (ws_config);
                    }
                }
            }

            app_settings.set_value ("right-config", logical_config_to_variant (right_config, target_id));

            var ws_config = yield create_config_from_workspace (target);
            var v = ws_config_to_variant (ws_config, target_id);
            app_settings.set_value ("target-config", v);
            app_settings.apply ();
        }


        public async bool restore_window_config (Window window)
        {
            string? id = yield wait_for_app_id (window);
            if (id == null) {
                return false;
            }

            var app_settings = get_settings_for_id (id);
            if (app_settings.get_value ("left-config").n_children () == 0 && 
                app_settings.get_value ("right-config").n_children () == 0 && 
                app_settings.get_value ("target-config").n_children () == 0) {
                return false;
            }

            yield assign_window (app_settings, window);
            return true;
        }

        async WorkspaceConfig create_config_from_workspace (Workspace ws)
        {
            var list = new WorkspaceConfig ();
            foreach (unowned Window window in ws.list_windows ()) {
                if (window.get_window_type () != NORMAL) {
                    continue;
                }

                string? id = yield wait_for_app_id (window);
                if (id != null) {
                    list.add (id);
                }
            }

            return list;
        }

        async void assign_window (GLib.Settings settings, Window window)
        {
            unowned Screen screen = wm.get_screen ();

            LogicalConfig left, right;
            WorkspaceConfig target;
            extract_configs (settings, out left, out right, out target);

            print ("Relevance left:\n");
            foreach (var c in left) {
                foreach (var id in c) {
                    print (id + "\n");
                }
            }

            print ("Relevance right:\n");
            foreach (var c in right) {
                foreach (var id in c) {
                    print (id + "\n");
                }
            }

            print ("Relevance target:\n");
            foreach (var id in target) {
                print (id + "\n");
            }
            print ("End\n");

            WorkspaceSolution[] scores = yield compute_solutions (left, right, target);
            int max_index = 0;
            
            print (scores[0].score.to_string () + " " + scores[0].add.to_string () + "\n");
            for (int i = 1; i < scores.length; i++) {
                if (scores[i].score > scores[max_index].score ||
                    // We will favour not adding workspaces when the scores are equal
                    (scores[i].score == scores[max_index].score) && (scores[i].add && !scores[max_index].add)) {
                    max_index = i;
                }

                print (scores[i].score.to_string () + " " + scores[i].add.to_string () + "\n");
            }

            unowned Workspace ws;
            if (scores[max_index].add) {
                int index = int.max (0, max_index);
                InternalUtils.insert_workspace_with_window (index, window);
                ws = screen.get_workspace_by_index (index);
            } else {
                ws = screen.get_workspace_by_index (max_index);
            }

            if (ws != null) {
                Idle.add (() => {
                    window.change_workspace (ws);
                    ws.activate_with_focus (window, screen.get_display ().get_current_time ());
                    return false;    
                });
            }
        }

        async WorkspaceSolution[] compute_solutions (
            LogicalConfig left,
            LogicalConfig right,
            WorkspaceConfig target)
        {
            unowned Screen screen = wm.get_screen ();
            int n_workspaces = screen.get_n_workspaces ();
            WorkspaceScore[] ws_scores = new WorkspaceScore[n_workspaces];
            
            unowned GLib.List<Workspace> workspaces = screen.get_workspaces ();
            int i = 0;
            print ("Workspace scores:\n");
            for (; workspaces != null; workspaces = workspaces.next) {
                Workspace ws = workspaces.data;
                int left_score = get_score_for_workspace (ws, left);
                int right_score = get_score_for_workspace (ws, right);
                int target_score = get_app_count (ws, target) * TARGET_REVELANCE;

                print ("%i: left: %i right: %i target: %i\n", i, left_score, right_score, target_score);

                ws_scores[i] = { ws, left_score, right_score, target_score };
                i++;
            }

            print ("End\n");

            bool has_dynamic = Prefs.get_dynamic_workspaces ();

            WorkspaceSolution[] scores = new WorkspaceSolution[n_workspaces];
            new Thread<void*> ("compute-scores", () => {
                for (i = 0; i < n_workspaces; i++) {
                    int target_score = ws_scores[i].target;
                    int score = target_score;
    
                    if (i > 0) {
                        for (int left_index = i - 1; left_index >= 0; left_index--) {
                            score += ws_scores[left_index].left;
                        }
                    }
    
                    if (i < n_workspaces - 1) {
                        for (int right_index = i + 1; right_index < n_workspaces; right_index++) {
                            score += ws_scores[right_index].right;
                        }
                    }
    
                    bool add = false;
                    if (target_score == 0 && has_dynamic) {
                        score += ws_scores[i].right; 
                        add = true;
                    }
    
                    scores[i] = { score, add };
                }

                Idle.add (compute_solutions.callback);
                return null;
            });

            yield;
            return scores;
        }

        static int get_score_for_workspace (Workspace ws, LogicalConfig logical_config)
        {
            int relevance_index = 0;
            int ws_score = 0;
            foreach (var ws_config in logical_config) {
                ws_score += get_app_count (ws, ws_config) * RELEVANCE_TABLE[relevance_index];
                relevance_index = int.min (relevance_index + 1, RELEVANCE_TABLE.length - 1);
            }

            return ws_score;
        }

        static void extract_configs (
            GLib.Settings settings,
            out LogicalConfig left, 
            out LogicalConfig right,
            out WorkspaceConfig target)
        {
            left = extract_variant_to_config (settings.get_value ("left-config"));
            right = extract_variant_to_config (settings.get_value ("right-config"));
            target = extract_ws_config (settings.get_value ("target-config"));
        }

        static LogicalConfig extract_variant_to_config (Variant variant)
        {
            var list = new LogicalConfig ();
            for (int i = 0; i < variant.n_children (); i++) {
                var ws_config = extract_ws_config (variant.get_child_value (i));
                list.add (ws_config);
            }

            return list;
        }

        static WorkspaceConfig extract_ws_config (Variant variant)
        {
            var list = new WorkspaceConfig ();
            for (int i = 0; i < variant.n_children (); i++) {
                string app_id;
                variant.get_child (i, "s", out app_id);
                list.add (app_id);
            }

            return list;
        }

        static Variant ws_config_to_variant (Gee.ArrayList<string> ws_config, string target_id)
        {
            var builder = new VariantBuilder (VariantType.STRING_ARRAY);
            foreach (string app_id in ws_config) {
                if (app_id == target_id) {
                    continue;
                }

                builder.add ("s", app_id);
            }

            return builder.end ();
        }

        static Variant logical_config_to_variant (LogicalConfig config, string target_id)
        {
            var builder = new VariantBuilder (string_matrix_type);
            foreach (var ws_config in config) {
                var variant = ws_config_to_variant (ws_config, target_id);
                builder.add_value (variant);
            }

            return builder.end ();
        }

        static int get_app_count (Workspace workspace, WorkspaceConfig ws_config)
        {
            int count = 0;
            foreach (unowned Window window in workspace.list_windows ()) {
                string? id = get_app_id_from_window (window);
                if (id == null) {
                    continue;
                }

                if (id in ws_config) {
                    count++;
                }
            }

            return count;
        }

        async string? wait_for_app_id (Window window)
        {
            string? id = app_ids_cache[window];
            if (id != null) {
                return id;
            }

            id = get_app_id_from_window (window);
            if (id == null) {
                ulong signal_id = 0U;
                uint timeout_id = 0U;
                signal_id = matcher_updated.connect (() => {
                    id = get_app_id_from_window (window);
                    if (id != null) {
                        Source.remove (timeout_id);
                        disconnect (signal_id);
                        Idle.add (wait_for_app_id.callback);
                    }
                });

                timeout_id = Timeout.add (GET_APP_ID_TIMEOUT, () => {
                    disconnect (signal_id);
                    Idle.add (wait_for_app_id.callback);
                    return false;
                });

                yield;
            }

            if (id != null) {
                app_ids_cache[window] = id;
            }

            return id;
        }

        static string? get_app_id_from_window (Window window)
        {
            unowned Bamf.Application app = matcher.get_application_for_xid ((uint32)window.get_xwindow ());
            if (app == null) {
                return null;
            }

            unowned string id = app.get_desktop_file ();
            return Path.get_basename (id);
        }
    }
}
