//
//  Copyright 2020 elementary, Inc. (https://elementary.io)
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

public class Gala.AppCache : GLib.Object {
    private Gee.HashMap<string, string> startup_wm_class_to_id;
    private Gee.HashMap<string, GLib.DesktopAppInfo> id_to_app;

    construct {
        startup_wm_class_to_id = new Gee.HashMap<string, string> ();
        id_to_app = new Gee.HashMap<string, GLib.DesktopAppInfo> ();

        rebuild_cache ();
    }

    private void rebuild_cache () {
        var app_infos = GLib.AppInfo.get_all ();

        foreach (unowned GLib.AppInfo app in app_infos) {
            var id = app.get_id ();
            var startup_wm_class = ((GLib.DesktopAppInfo)app).get_startup_wm_class ();

            id_to_app[id] = (GLib.DesktopAppInfo)app;

            if (startup_wm_class == null) {
                continue;
            }

            var old_id = startup_wm_class_to_id[startup_wm_class];
            if (old_id == null || id == startup_wm_class) {
                startup_wm_class_to_id[startup_wm_class] = id;
            }
        }
    }

    public GLib.DesktopAppInfo? lookup_id (string? id) {
        if (id == null) {
            return null;
        }

        return id_to_app[id];
    }

    public GLib.DesktopAppInfo? lookup_startup_wmclass (string? wm_class) {
        if (wm_class == null) {
            return null;
        }

        var id = startup_wm_class_to_id[wm_class];
        if (id == null) {
            return null;
        }

        return id_to_app[id];
    }
}
