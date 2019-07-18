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
    string? app_type = keybindings_to_types.get (keybinding);
    DesktopAppInfo? info;

    // get app_id of application
    if (keybinding == "quickswitch-terminal") { // can't set default application for terminal
      info = new DesktopAppInfo ("io.elementary.terminal.desktop");
    } else { 
      info = new DesktopAppInfo (AppInfo.get_default_for_type (app_type, false).get_id ());
    }

    if (info == null) {
      warning("Failed to get DesktopAppInfo for %s.", app_type);
      return;
    }

    // get xids for application
    var xids = Bamf.Matcher.get_default ().get_xids_for_application (info.filename);

    // launch application if not running
    if (xids.length == 0) {
      launch_application (info);
      return;
    }

    // filter all windows by xid
    var app_windows = new SList<Meta.Window> ();

    foreach (var workspace in screen.get_workspaces ()) {
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

        // skip windows that are on all workspace except we're currently
        // processing the workspace it actually belongs to
        if (win.is_on_all_workspaces () && win.get_workspace () != workspace)
          continue;

        for (var i = 0; i < xids.length; i++) {
          if (xids.index (i) == (uint32) win.get_xwindow ()) {
            app_windows.append (win);
            break;
          }
        }
      }
    }

    // launch application if no window found
    if (app_windows.length () == 0) {
      launch_application (info);
      return;
    }

    //  focus highest window of application if no window of application has focus
    //  focus lowest window of application if highest window has focus
    var sorted_windows = display.sort_windows_by_stacking (app_windows);
    var active_window = display.get_focus_window ();
    var last_window = sorted_windows.data;
    var first_window = sorted_windows.last ().data;
    var time = display.get_current_time ();

    if (active_window != first_window) { // activate highest window
      debug("focus highest %s", info.get_display_name ());
      first_window.activate (time);
    } else { // activate lowest window
      debug("focus lowest %s", info.get_display_name ());
      last_window.activate (time);
    }
  }

  public override void destroy ()
  {
  }
}

private void launch_application (DesktopAppInfo info) {
  try {
    info.launch (null, null);
  } catch {
    warning("Failed to launch %s.", info.get_display_name ());
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
