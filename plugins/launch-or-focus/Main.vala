/*
 * Copyright 2021 Felix Andreas <fandreas@physik.hu-berlin.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Gala.Plugins.LaunchOrFocus : Gala.Plugin {
    private const int MAX_CUSTOM_SHORTCUTS = 10;

    private Gala.WindowManager? wm = null;
    private HashTable<string, string> name_to_type;
    private GLib.Settings settings_custom;

    construct {
        name_to_type = new HashTable<string, string> (str_hash, str_equal);
        name_to_type.insert ("webbrowser", "x-scheme-handler/http");
        name_to_type.insert ("emailclient", "x-scheme-handler/mailto");
        name_to_type.insert ("calendar", "text/calendar");
        name_to_type.insert ("videoplayer", "video/x-ogm+ogg");
        name_to_type.insert ("musicplayer", "audio/x-vorbis+ogg");
        name_to_type.insert ("imageviewer", "image/jpeg");
        name_to_type.insert ("texteditor", "text/plain");
        name_to_type.insert ("filebrowser", "inode/directory");
        name_to_type.insert ("terminal", "");
    }

    public override void initialize (Gala.WindowManager wm) {
        this.wm = wm;
        unowned Meta.Display display = wm.get_display ();
        var settings = new GLib.Settings (Config.SCHEMA + ".keybindings.launch-or-focus");
        settings_custom = new GLib.Settings (Config.SCHEMA + ".keybindings.launch-or-focus.custom-applications");

        name_to_type.foreach ((name, _) => {
            display.add_keybinding (name, settings, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) handler);
        });
        for (var i = 0; i < MAX_CUSTOM_SHORTCUTS; i ++) {
            display.add_keybinding (@"application-$(i)", settings_custom, Meta.KeyBindingFlags.NONE, (Meta.KeyHandlerFunc) handler);
        }
    }

    public override void destroy () {}

    [CCode (instance_pos = -1)]
    void handler (Meta.Display display, Meta.Window? window, Clutter.KeyEvent event, Meta.KeyBinding binding) {
        debug("handle!");
        string name = binding.get_name ();
        string? content_type = name_to_type.get (name);
        string desktop_id;
        if (content_type == null) {
            var index = int.parse(name.substring (-1));
            desktop_id = settings_custom.get_strv ("desktop-ids")[index];
        } else if (name == "terminal") { // can't set default application for terminal
            desktop_id = "io.elementary.terminal.desktop";
        } else {
            desktop_id = AppInfo.get_default_for_type (content_type, false).get_id ();
        } 

        var app_info = new GLib.DesktopAppInfo (desktop_id);
        if (event.has_control_modifier ()) {
            launch (app_info);
        } else {
            launch_or_focus (app_info);
        }
    }

    /*
    * Case A: application is not running           --> launch a new instance
    * Case B: application is running without focus --> focus instance with highest z-index
    * Case C: application is running and has focus --> focus another instance (lowest z-index)
    */
    private void launch_or_focus (GLib.DesktopAppInfo app_info) {
        if (app_info == null) {
            warning("Failed to get DesktopAppInfo");
            return;
        }

        unowned Meta.Display display = wm.get_display ();
        var windows = new SList<Meta.Window> ();
        foreach (unowned Meta.Window window in display.get_tab_list (Meta.TabList.NORMAL, null)) {
            if (app_info.equal (Utils.get_app_from_window (window))) {
                windows.append (window);
            }
        }

        // Case A
        if (windows.length () == 0) {
            launch (app_info);
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

    private void launch (GLib.DesktopAppInfo app_info) {
        try {
            app_info.launch (null, null);
        } catch (Error e) {
            critical ("Unable to launch app: %s", e.message);
        }
    }
}

public Gala.PluginInfo register_plugin () {
	return {
		"launch-or-focus",
		"Felix Andreas",
		typeof (Gala.Plugins.LaunchOrFocus),
		Gala.PluginFunction.ADDITION,
		Gala.LoadPriority.IMMEDIATE
	};
}
