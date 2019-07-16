
using Meta;
namespace Gala
{ 
    public class WorkspaceWindowRestore : Object { 
        public unowned WindowManager wm { get; construct; }

        Gee.HashMap<int, Meta.Workspace> bindings;

        static Bamf.Matcher matcher;
        static construct 
        {
            matcher = Bamf.Matcher.get_default ();
        }

        construct
        {
            bindings = new Gee.HashMap<int, Meta.Workspace> ();
        }

        public WorkspaceWindowRestore (WindowManager wm)
        {
            Object (wm: wm);
        }

        public void save_window_config (Window window)
        {
            unowned Bamf.Application app = Bamf.Matcher.get_default ().get_application_for_xid ((uint32)window.get_xwindow ());
            if (app == null) {
                return;
            }

            unowned string id = app.get_desktop_file ();
            if (id == null) {
                return;
            }

            var schema = BehaviorSettings.get_default ().schema;
            Variant[] config_array = {};

            var existing = schema.get_value ("workspace-configs");
            for (int i = 0; i < existing.n_children (); i++) {
                string app_id;
                int ws_id;
                existing.get_child (i, "(si)", out app_id, out ws_id);

                if (app_id == id) {
                    continue;
                }

                var app_config = new Variant ("(si)", app_id, ws_id);
                config_array += app_config;
            }

            var app_config = new Variant ("(si)", id, window.get_workspace ().index ());
            config_array += app_config;

            var configs = new Variant.array (null, config_array);
            schema.set_value ("workspace-configs", configs);
        }

        public void restore_window_config (Window window)
        {           
            string? id = get_app_id_from_window (window);
            if (id == null) {
                return;
            }

            var configs = new Gee.HashMap<int, Gee.ArrayList<string>> ();
            //  AppWorkspaceConfig[] configs = {};

            int config_index = 0;
            AppWorkspaceConfig? target = null;

            var existing = BehaviorSettings.get_default ().schema.get_value ("workspace-configs");
            for (int i = 0; i < existing.n_children (); i++) {
                string app_id;
                int ws_id;
                existing.get_child (i, "(si)", out app_id, out ws_id);

                if (app_id == id) {
                    target = { app_id, ws_id };
                    config_index = i;
                }

                if (ws_id in configs) {
                    configs[ws_id].add (app_id);
                } else {
                    configs[ws_id] = new Gee.ArrayList<string> ();
                    configs[ws_id].add (app_id);
                }
            }

            if (target != null) {
                assign_window (configs, window, target);
            }
        }

        //  void assign_window (Gee.HashMap<int, Gee.ArrayList<string>> configs, Window window, AppWorkspaceConfig target)
        //  {
        //      //  if (bindings.size == 0) {
        //      //      bindings[config_index] = window.get_workspace ();
        //      //      return;
        //      //  }

        //      /**
        //       * If there's only one workspace and no windows on it
        //       * we will bail out.
        //       */
        //      unowned Screen screen = wm.get_screen ();
        //      if (screen.get_n_workspaces () == 1 && 
        //          Utils.get_n_windows (screen.get_workspace_by_index (0)) == 0) {
        //          return;
        //      }

        //      var ids = configs[target.workspace];
        //      ids.remove (target.id);

        //      foreach (var id in ids) {
        //          print (id.to_string () + "\n");
        //      }

        //      /**
        //       * We will first check if the window shouldn't belong
        //       * to an already existing workspace that contains apps
        //       * that should be grouped with it.
        //       */
        //      unowned Workspace? candidate = null;
        //      int max_apps_found = 0;
            
        //      int n = screen.get_n_workspaces ();
        //      for (int i = 0; i < n; i++) {
        //          unowned Workspace workspace = screen.get_workspace_by_index (i);
        //          int count = get_app_count (workspace, ids);
        //          if (count > max_apps_found) {
        //              max_apps_found = count;
        //              candidate = workspace;
        //          }
        //      }

        //      if (candidate != null) {
        //          window.change_workspace (candidate);
        //          candidate.activate_with_focus (window, screen.get_display ().get_current_time ());
        //          return;
        //      }

            

        //      //  int closest_left = 0;
        //      //  int closest_right = n - 1;

        //      //  if (target_index in bindings.keys) {
        //      //      window.change_workspace (bindings[target_index]);
        //      //      return;
        //      //  }

        //      //  foreach (int _config_index in bindings.keys) {
        //      //      if (_config_index > closest_left && _config_index < target_index) {
        //      //          closest_left = _config_index;
        //      //      }


        //      //      if (_config_index < closest_right && _config_index > target_index) {
        //      //          closest_right = _config_index;
        //      //      }
        //      //  }

        //      //  print ("LEFT: " + closest_left.to_string () + "\n");
        //      //  print ("RIGHT: " + closest_right.to_string () + "\n");

        //      //  for (int i = 1; i < n; i++) {
        //      //      unowned Workspace workspace = screen.get_workspace_by_index (i);
        //      //      if ()
        //      //  }



        //      //  print ("TARGET: " + target_index.to_string () + "\n");
        //  }

        void assign_window (Gee.HashMap<int, Gee.ArrayList<string>> configs, Window window, AppWorkspaceConfig target)
        {
            unowned Screen screen = wm.get_screen ();

            print ("ASSIGN".to_string () + "\n");
            var search_list = new Gee.ArrayList<Gee.ArrayList<string>> ();
            int offset = 0;
            if (target.workspace == 0) {
                int n_workspaces = screen.get_n_workspaces () - (Prefs.get_dynamic_workspaces () ? 1 : 0);
                if (n_workspaces > 1) {
                    search_list.add (configs[target.workspace]);
                    if (configs.size > target.workspace + 1) {
                        search_list.add (configs[target.workspace + 1]);
                    }
                } else {
                    unowned Workspace ws = screen.get_workspace_by_index (0);
                    window.change_workspace (ws);
                    ws.activate_with_focus (window, screen.get_display ().get_current_time ());
                    return;
                }
            } else {
                offset = 1;
                if (configs.size > target.workspace + 1) {
                    search_list.add (configs[target.workspace - 1]);
                    search_list.add (configs[target.workspace]);
                    search_list.add (configs[target.workspace + 1]);
                } else {
                    search_list.add (configs[target.workspace - 1]);
                    search_list.add (configs[target.workspace]);
                }
            }

            print ("COMPUTE SCORES".to_string () + "\n");
            print ("OFFSET: ".to_string () + offset.to_string () + "\n");
            print ("SEARCH FOR:\n");
            foreach (var ws_c in search_list) {
                foreach (var app_id in ws_c) {
                    print (app_id.replace ("/usr/share/applications/", "") + " ");
                }

                print ("\n");
            }
            WorkspaceRevelanceScore[] scores = compute_scores (search_list, offset);
            for (int i = 0; i < scores.length; i++) {
                print (scores[i].score.to_string () + " " + scores[i].should_add_workspace.to_string () + "\n");
            }

            //  print (scores[0].to_string () + " ");
            int max_index = 0;
            for (int i = 1; i < scores.length; i++) {
                if (scores[i].score > scores[max_index].score) {
                    max_index = i;
                }
            }

            unowned Meta.Workspace? ws = null;
            if (scores[max_index].should_add_workspace) {
                ws = screen.append_new_workspace (false, screen.get_display ().get_current_time ());
                screen.reorder_workspace (ws, max_index + offset);
            } else {
                ws = screen.get_workspace_by_index (max_index + offset);
            }

            window.change_workspace (ws);
            ws.activate_with_focus (window, screen.get_display ().get_current_time ());
        }

        struct WorkspaceRevelanceScore {
            int score;
            bool should_add_workspace;
        }

        WorkspaceRevelanceScore[] compute_scores (Gee.ArrayList<Gee.ArrayList<string>> search_list, int target_index)
        {
            unowned Screen screen = wm.get_screen ();
            int n_workspaces = screen.get_n_workspaces ();
            WorkspaceRevelanceScore[] scores = new WorkspaceRevelanceScore[n_workspaces];
            for (int i = 0; i < n_workspaces; i++) {
                int ws_score = 0;
                bool should_add_workspace = false;
                for (int j = 0; j < search_list.size; j++) {
                    unowned Workspace ws = screen.get_workspace_by_index (i + j);
                    if (ws == null) {
                        continue;
                    }

                    uint score = get_app_count (ws, search_list[j]);
                    if (score == 0 && j == target_index && (j + 1 < search_list.size)) {
                        score = get_app_count (ws, search_list[j + 1]);
                        should_add_workspace = true;
                    }

                    ws_score += (int)score;
                }

                scores[i] = { ws_score, should_add_workspace };
            }

            return scores;
        }

        static uint get_app_count (Workspace workspace, Gee.ArrayList<string> app_ids)
        {
            uint count = 0;
            foreach (unowned Window window in workspace.list_windows ()) {
                string? id = get_app_id_from_window (window);
                if (id == null) {
                    continue;
                }

                if (id in app_ids) {
                    count++;
                }
            }

            return count;
        }

        static string? get_app_id_from_window (Window window)
        {
            unowned Bamf.Application app = Bamf.Matcher.get_default ().get_application_for_xid ((uint32)window.get_xwindow ());
            if (app == null) {
                return null;
            }

            unowned string id = app.get_desktop_file ();
            return id;
        }

    //  static AppWorkspaceConfig[] filter_by_similar_config (AppWorkspaceConfig[] configs, AppWorkspaceConfig target)
    //  {
    //      AppWorkspaceConfig[] filtered = {};
    //      foreach (var config in configs) {
    //          if (config.workspace == target.workspace && config.id != target.id) {
    //              filtered += config;
    //          }
    //      }

    //      return filtered;
    //  }
    }
}