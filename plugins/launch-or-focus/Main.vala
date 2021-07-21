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
    private const string SCHEMA_DEFAULT = ".keybindings.launch-or-focus";

    private Gala.WindowManager? wm = null;
    private unowned Meta.Display? display = null;
    private GLib.Settings settings_default;

    public override void initialize (Gala.WindowManager wm) {
        this.wm = wm;
        this.display = wm.get_display ();

        settings_default = new GLib.Settings (Config.SCHEMA + SCHEMA_DEFAULT);

        add_default_keybinding ("webbrowser", "x-scheme-handler/http");
        add_default_keybinding ("emailclient", "x-scheme-handler/mailto");
        add_default_keybinding ("calendar", "text/calendar");
        add_default_keybinding ("videoplayer", "video/x-ogm+ogg");
        add_default_keybinding ("musicplayer", "audio/x-vorbis+ogg");
        add_default_keybinding ("imageviewer", "image/jpeg");
        add_default_keybinding ("texteditor", "text/plain");
        add_default_keybinding ("filebrowser", "inode/directory");
        // can't set default application for terminal
        display.add_keybinding (
            "elementary-terminal",
            settings_default,
            Meta.KeyBindingFlags.NONE,
            (display, window, event, binding) => launch_or_focus ("io.elementary.terminal.desktop")
        );
    }

    private void add_default_keybinding (string name, string content_type) {
        display.add_keybinding (
            name,
            settings_default,
            Meta.KeyBindingFlags.NONE,
            (display, window, event, binding) => {
                launch_or_focus (GLib.AppInfo.get_default_for_type (content_type, false).get_id ());
            }
        );
    }

    public override void destroy () {}

    /*
    * Case A: application is not running           --> launch a new instance
    * Case B: application is running without focus --> focus instance with highest z-index
    * Case C: application is running and has focus --> focus another instance (lowest z-index)
    */
    private void launch_or_focus (string desktop_id) {
        var app_info = new GLib.DesktopAppInfo (desktop_id);
        if (app_info == null) {
            warning (@"Could not find DesktopAppInfo for desktop-id “$(desktop_id)“");
            return;
        }

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
