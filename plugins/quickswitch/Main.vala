//
//  Copyright (C) 2019 Felix Andreas
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//


public class Gala.Plugins.QuickSwitch : Gala.Plugin
{
  HashTable<string, string> keybindings_to_types;

  construct {
    keybindings_to_types = new HashTable<string, string> (str_hash, str_equal);
    keybindings_to_types.insert ("quickswitch-editor", "text/plain");
    keybindings_to_types.insert ("quickswitch-files", "inode/directory");
    keybindings_to_types.insert ("quickswitch-terminal", "io.elementary.terminal");
    keybindings_to_types.insert ("quickswitch-webbrowser", "x-scheme-handler/http");
    keybindings_to_types.insert ("quickswitch-debug", "quickswitch_debug"); // only for debugging, will be deleted
  }

  public override void initialize (Gala.WindowManager wm)
  {
    unowned Meta.Display display = wm.get_screen ().get_display ();

    var settings = new GLib.Settings (Config.SCHEMA + ".keybindings");

    keybindings_to_types.foreach ((keybinding, _) => {
      display.add_keybinding (keybinding, settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) on_initiate);
    });
  }

  [CCode (instance_pos = -1)]
  void on_initiate (Meta.Display display, Meta.Screen screen,
    Meta.Window? window, Clutter.KeyEvent event, Meta.KeyBinding binding)
  {

    var keybinding = binding.get_name ();
    string type = keybindings_to_types.get (keybinding);
    string app_id;
    DesktopAppInfo appinfo;

    // get app_id of application
    if (keybinding == "quickswitch-terminal") { // can't set default application for terminal
      app_id = "io.elementary.terminal";
      appinfo = new DesktopAppInfo ("io.elementary.terminal.desktop");
    } else {
      app_id = AppInfo.get_default_for_type (type, false).get_id ();
      appinfo = new DesktopAppInfo (app_id);
      if (app_id.has_suffix (".desktop")) {
        app_id = app_id.substring (0, app_id.length + app_id.index_of_nth_char (-8)); // TODO: rename to app_id (maybe use BAMf)
      }
    }

    if (app_id == null) {
      warning("Failed quick switch for %s.", type);
      return;
    }
      
    debug("app_id is : %s", app_id);

    unowned Meta.Window active_window = display.get_focus_window ();
    var workspaces = new List<Meta.Workspace> ();
    var all_windows = new SList<Meta.Window> ();

    foreach (var workspace in screen.get_workspaces ())
      workspaces.append (workspace);

    foreach (var workspace in workspaces) {
      foreach (var win in workspace.list_windows ()) {
        if (win.window_type != Meta.WindowType.NORMAL && 
          win.window_type != Meta.WindowType.DOCK && 
          win.window_type != Meta.WindowType.DIALOG || 
          win.is_attached_dialog ()) {
          var actor = win.get_compositor_private () as Meta.WindowActor;
          if (actor != null)
            actor.hide ();
          continue;
        }
        if (win.window_type == Meta.WindowType.DOCK)
          continue;

        if (app_id[-4:-1] == win.get_wm_class_instance ()[-4:-1]) { // workaround:
          all_windows.append (win);                                 // compare last for characters 
        }                                                           // of app_id with wm_class
      }
    }

    if (all_windows.length () == 0) {
      debug("no windows of this wm_class!, start application!");
      try {
        appinfo.launch (null, null);
      } catch {
        warning("Failed to launch %s.", type);
      }
      return;
    }

    var sorted_windows = display.sort_windows_by_stacking (all_windows);
    var last_window = sorted_windows.data;
    var first_window = sorted_windows.last ().data;
    var time = display.get_current_time ();

    if (active_window != first_window) { // activate highest window
      debug("focus highest %s", app_id);
      first_window.activate (time);
    } else { // activate lowest window
      debug("focus lowest %s", app_id);
      last_window.activate (time);
    }
  }

  public override void destroy ()
  {
  }
}

public Gala.PluginInfo register_plugin ()
{
	return {
		"Quick Switch",
		"Felix Andreas",
		typeof (Gala.Plugins.QuickSwitch),
		Gala.PluginFunction.ADDITION,
		Gala.LoadPriority.IMMEDIATE
	};
}
