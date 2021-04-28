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
        keybindings_to_types.insert ("application-webbrowser", "x-scheme-handler/http");
        keybindings_to_types.insert ("application-emailclient", "x-scheme-handler/mailto");
        keybindings_to_types.insert ("application-calendar", "text/calendar");
        keybindings_to_types.insert ("application-videoplayer", "video/x-ogm+ogg");
        keybindings_to_types.insert ("application-musicplayer", "audio/x-vorbis+ogg");
        keybindings_to_types.insert ("application-imageviewer", "image/jpeg");
        keybindings_to_types.insert ("application-texteditor", "text/plain");
        keybindings_to_types.insert ("application-filemanager", "inode/directory");
        keybindings_to_types.insert ("application-terminal", "");
    }

    public override void initialize (Gala.WindowManager wm) {
        this.wm = wm;
        unowned Meta.Display display = wm.get_display ();
        var settings = new GLib.Settings (Config.SCHEMA + ".keybindings.applications");

        keybindings_to_types.foreach ((keybinding, _) => {
            display.add_keybinding (keybinding, settings, Meta.KeyBindingFlags.NONE,
                (Meta.KeyHandlerFunc) handler_default_application);
        });

        settings_custom = new GLib.Settings (Config.SCHEMA + ".keybindings.applications.custom");
        for (var i = 0; i < MAX_CUSTOM_SHORTCUTS; i ++) {
            display.add_keybinding (
                @"application-custom$(i)",
                settings_custom,
                Meta.KeyBindingFlags.NONE, 
                (Meta.KeyHandlerFunc) handler_custom_application
            );
        }
    }

    public override void destroy () {
    }

    [CCode (instance_pos = -1)]
    void handler_default_application (Meta.Display display, Meta.Window? window,
        Clutter.KeyEvent event, Meta.KeyBinding binding) {
        string keybinding = binding.get_name ();
        string desktop_id;
        if (keybinding == "application-terminal") { // can't set default application for terminal
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

    /*
    * Case A: application is not running           -->  a new instance
    * Case B: application is running without focus --> focus instance with highest z-index
    * Case C: application is running and has focus --> focus another instance (lowest z-index)
    */
    void focus_by_desktop_id (string desktop_id) {
        DesktopAppInfo info = new DesktopAppInfo (desktop_id);
        if (info == null) {
            warning("Failed to get DesktopAppInfo");
            return;
        }

        unowned Meta.Display display = wm.get_display ();
        var windows = new SList<Meta.Window> ();
        foreach (unowned Meta.Window window in display.get_tab_list (Meta.TabList.NORMAL, null)) {
            if (Utils.window_to_desktop_cache[window].equal(info)) {
                windows.append (window);
            }
        }

        // Case A
        if (windows.length () == 0) {
            try {
                info.launch (null, null);
            } catch {
                warning("Failed to launch %s.", info.get_display_name ());
            }
            return;
        }

        var sorted_windows = display.sort_windows_by_stacking (windows);
        var active_window = display.get_focus_window ();
        var last_window = sorted_windows.data;
        var first_window = sorted_windows.last ().data;
        var time = display.get_current_time ();

        // Case B
        if (active_window != first_window) {
            first_window.activate (time);
        // Case C
        } else {
            last_window.activate (time);
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
