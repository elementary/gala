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

public class Gala.Plugins.AppShortcuts : Gala.Plugin
{
  HashTable<string, string> keybindings_to_types;
  GLib.Settings settings_custom;
  const int MAX_CUSTOM_SHORTCUTS = 10;

  construct {
    keybindings_to_types = new HashTable<string, string> (str_hash, str_equal);
    keybindings_to_types.insert ("applications-webbrowser", "x-scheme-handler/http");
    keybindings_to_types.insert ("applications-emailclient", "x-scheme-handler/mailto");
    keybindings_to_types.insert ("applications-calendar", "text/calendar");
    keybindings_to_types.insert ("applications-videoplayer", "video/x-ogm+ogg");
    keybindings_to_types.insert ("applications-musicplayer", "audio/x-vorbis+ogg");
    keybindings_to_types.insert ("applications-imageviewer", "image/jpeg");
    keybindings_to_types.insert ("applications-texteditor", "text/plain");
    keybindings_to_types.insert ("applications-filebrowser", "inode/directory");
    keybindings_to_types.insert ("applications-terminal", "");
  }

  public override void initialize (Gala.WindowManager wm)
  {
    unowned Meta.Display display = wm.get_screen ().get_display ();
    
    var settings = new GLib.Settings (Config.SCHEMA + ".keybindings.applications");

    keybindings_to_types.foreach ((keybinding, _) => {
      display.add_keybinding (keybinding, settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) handler_default_applications);
    });
  

    settings_custom = new GLib.Settings (Config.SCHEMA + ".keybindings.applications.custom");

    for (var i = 0; i < MAX_CUSTOM_SHORTCUTS; i ++) {
      display.add_keybinding ("applications-custom" + i.to_string (), settings_custom,
        Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) handler_custom_applications);
    }
  }
  

  [CCode (instance_pos = -1)]
  void handler_default_applications (Meta.Display display, Meta.Screen screen,
  Meta.Window? window, Clutter.KeyEvent event, Meta.KeyBinding binding)
  {
    string keybinding = binding.get_name ();
    string desktop_id;

    if (keybinding == "applications-terminal") { // can't set default application for terminal
      desktop_id = "io.elementary.terminal.desktop";
    } else { 
      desktop_id = AppInfo.get_default_for_type (keybindings_to_types.get (keybinding), false).get_id ();
    }

    focus_by_desktop_id (display, screen, window, desktop_id);
  }

  [CCode (instance_pos = -1)]
  void handler_custom_applications (Meta.Display display, Meta.Screen screen,
  Meta.Window? window, Clutter.KeyEvent event, Meta.KeyBinding binding)
  {
    string keybinding = binding.get_name ();
    var index = int.parse(keybinding.substring (-1));
    var desktop_id = settings_custom.get_strv ("desktop-ids") [index];

    focus_by_desktop_id (display, screen, window, desktop_id);
  }

  void focus_by_desktop_id (Meta.Display display, Meta.Screen screen, Meta.Window? window, string desktop_id)
  {
    DesktopAppInfo info = new DesktopAppInfo (desktop_id);

    if (info == null) {
      warning("Failed to get DesktopAppInfo");
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
      first_window.activate (time);
    } else { // activate lowest window
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
		"Application Shortcuts",
		"Felix Andreas",
		typeof (Gala.Plugins.AppShortcuts),
		Gala.PluginFunction.ADDITION,
		Gala.LoadPriority.IMMEDIATE
	};
} 
