//
//  Copyright (C) 2020 Felix Andreas
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <http://www.gnu.org/licenses/>.
//

public class Gala.Plugins.AppShortcuts : Gala.Plugin {
    private Gala.WindowManager? wm = null;
    private HashTable<string, string> keybindings_to_types;
    private GLib.Settings settings_custom;
    private int MAX_CUSTOM_SHORTCUTS = 10;

    construct {
        keybindings_to_types = new HashTable<string, string> (str_hash, str_equal);
        keybindings_to_types.insert ("applications-webbrowser", "x-scheme-handler/http");
        keybindings_to_types.insert ("applications-emailclient", "x-scheme-handler/mailto");
        keybindings_to_types.insert ("applications-calendar", "text/calendar");
        keybindings_to_types.insert ("applications-videoplayer", "video/x-ogm+ogg");
        keybindings_to_types.insert ("applications-musicplayer", "audio/x-vorbis+ogg");
        keybindings_to_types.insert ("applications-imageviewer", "image/jpeg");
        keybindings_to_types.insert ("applications-texteditor", "text/plain");
        keybindings_to_types.insert ("applications-filemanager", "inode/directory");
        keybindings_to_types.insert ("applications-terminal", "");
    }

    public override void initialize (Gala.WindowManager wm) {
        this.wm = wm;
        unowned Meta.Display display = wm.get_display ();
        var settings = new GLib.Settings (Config.SCHEMA + ".keybindings.applications");

        keybindings_to_types.foreach ((keybinding, _) => {
            display.add_keybinding (keybinding, settings, Meta.KeyBindingFlags.NONE,
                (Meta.KeyHandlerFunc) handler_default_application);
        });

        display.add_keybinding ("applications-same", settings, Meta.KeyBindingFlags.NONE,
            (Meta.KeyHandlerFunc) handler_same_application);

        settings_custom = new GLib.Settings (Config.SCHEMA + ".keybindings.applications.custom");
        for (var i = 0; i < MAX_CUSTOM_SHORTCUTS; i ++) {
            display.add_keybinding ("applications-custom" + i.to_string (), settings_custom,
                Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) handler_custom_application);
        }
    }

    public override void destroy () {
    }

    [CCode (instance_pos = -1)]
    void handler_default_application (Meta.Display display, Meta.Window? window,
        Clutter.KeyEvent event, Meta.KeyBinding binding) {
        string keybinding = binding.get_name ();
        string desktop_id;
        if (keybinding == "applications-terminal") { // can't set default application for terminal
            desktop_id = "io.elementary.terminal.desktop";
        } else {
            desktop_id = AppInfo.get_default_for_type (keybindings_to_types.get (keybinding), false).get_id ();
        }

        focus_by_desktop_id (desktop_id);
    }

    [CCode (instance_pos = -1)]
    void handler_custom_application (Meta.Display display, Meta.Window? window,
        Clutter.KeyEvent event, Meta.KeyBinding binding) {
        string keybinding = binding.get_name ();
        var index = int.parse(keybinding.substring (-1));
        var desktop_id = settings_custom.get_strv ("desktop-ids")[index];
        focus_by_desktop_id (desktop_id);
    }

    [CCode (instance_pos = -1)]
    void handler_same_application (Meta.Display display, Meta.Window? window,
        Clutter.KeyEvent event, Meta.KeyBinding binding) {
        var active_window = display.get_focus_window ();
        var wm_class = active_window.get_wm_class ();
        foreach (unowned Meta.Window other in get_window_stack ()) {
            if (other.get_wm_class () == wm_class && other != active_window) {
                other.activate (display.get_current_time ());
                return;
            }
        }
    }

    /*
    * Case A: application is not running           --> open a new instance
    * Case B: application is running without focus --> focus instance with highest z-index
    * Case C: application is running and has focus --> focus another instance (lowest z-index)
    */
    void focus_by_desktop_id (string desktop_id) {
        DesktopAppInfo info = new DesktopAppInfo (desktop_id);
        if (info == null) {
            warning("Failed to get DesktopAppInfo");
            return;
        }

        var xids = Bamf.Matcher.get_default ().get_xids_for_application (info.filename);
        if (xids.length == 0) {
            launch_application (info);
            return;
        }

        var windows = new SList<Meta.Window> ();
        foreach (unowned Meta.Window window in get_window_stack ()) {
            for (var j = 0; j < xids.length; j++) {
                if (xids.index (j) == (uint32) window.get_xwindow ()) {
                    windows.append (window);
                    break;
                }
            }
        }

        if (windows.length () == 0) {
            launch_application (info);
            return;
        }

        unowned Meta.Display display = wm.get_display ();
        var sorted_windows = display.sort_windows_by_stacking (windows);
        var active_window = display.get_focus_window ();
        var last_window = sorted_windows.data;
        var first_window = sorted_windows.last ().data;
        var time = display.get_current_time ();
        if (active_window != first_window) {
            first_window.activate (time);
        } else {
            last_window.activate (time);
        }
    }

    private SList<Meta.Window> get_window_stack () {
        var windows = new SList<Meta.Window> ();
        unowned Meta.Display display = wm.get_display ();
        unowned Meta.WorkspaceManager manager = display.get_workspace_manager ();
        for (int i = 0; i < manager.get_n_workspaces (); i++) {
            unowned Meta.Workspace workspace = manager.get_workspace_by_index (i);
            foreach (unowned Meta.Window window in workspace.list_windows ()) {
                if (window.window_type != Meta.WindowType.NORMAL &&
                    window.window_type != Meta.WindowType.DOCK &&
                    window.window_type != Meta.WindowType.DIALOG ||
                    window.is_attached_dialog ()) {
                    var actor = window.get_compositor_private () as Meta.WindowActor;
                    if (actor != null)
                        actor.hide ();
                    continue;
                }

                if (window.window_type == Meta.WindowType.DOCK) {
                    continue;
                }

                // skip windows that are on all workspace except we're currently
                // processing the workspace it actually belongs to
                if (window.is_on_all_workspaces () && window.get_workspace () != workspace) {
                    continue;
                }

                windows.append (window);
            }
        }

        return windows;
    }

    private void launch_application (DesktopAppInfo info) {
        try {
            info.launch (null, null);
        } catch {
            warning("Failed to launch %s.", info.get_display_name ());
        }
    }
}

public Gala.PluginInfo register_plugin () {
	return {
		"Application Shortcuts",
		"Felix Andreas",
		typeof (Gala.Plugins.AppShortcuts),
		Gala.PluginFunction.ADDITION,
		Gala.LoadPriority.IMMEDIATE
	};
}
