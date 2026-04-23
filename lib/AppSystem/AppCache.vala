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
    public signal void changed ();

    private const int DEFAULT_TIMEOUT_SECONDS = 3;

    private GLib.HashTable<unowned string, unowned string> startup_wm_class_to_id;
    private GLib.HashTable<unowned string, GLib.DesktopAppInfo> id_to_app;

    private GLib.AppInfoMonitor app_info_monitor;

    private uint queued_update_id = 0;

    construct {
        startup_wm_class_to_id = new GLib.HashTable<unowned string, unowned string> (str_hash, str_equal);
        id_to_app = new GLib.HashTable<unowned string, GLib.DesktopAppInfo> (str_hash, str_equal);

        app_info_monitor = GLib.AppInfoMonitor.@get ();
        app_info_monitor.changed.connect (queue_cache_update);

        rebuild_cache.begin ();
    }

    private void queue_cache_update () {
        if (queued_update_id != 0) {
            GLib.Source.remove (queued_update_id);
        }

        queued_update_id = GLib.Timeout.add_seconds (DEFAULT_TIMEOUT_SECONDS, () => {
            rebuild_cache.begin ((obj, res) => {
                rebuild_cache.end (res);
                changed ();

                queued_update_id = 0;
            });

            return GLib.Source.REMOVE;
        });
    }

    private async void rebuild_cache () {
        SourceFunc callback = rebuild_cache.callback;

        new Thread<void> ("rebuild_cache", () => {
            lock (startup_wm_class_to_id) {
                startup_wm_class_to_id.remove_all ();
                id_to_app.remove_all ();

                var app_infos = GLib.AppInfo.get_all ();

                foreach (unowned GLib.AppInfo app in app_infos) {
                    unowned string id = app.get_id ();
                    unowned string? startup_wm_class = ((GLib.DesktopAppInfo)app).get_startup_wm_class ();

                    id_to_app[id] = (GLib.DesktopAppInfo)app;

                    if (startup_wm_class == null) {
                        continue;
                    }

                    unowned var old_id = startup_wm_class_to_id[startup_wm_class];
                    if (old_id == null || id == startup_wm_class) {
                        startup_wm_class_to_id[startup_wm_class] = id;
                    }
                }
            }

            Idle.add ((owned)callback);
        });

        yield;
    }

    public unowned GLib.DesktopAppInfo? lookup_id (string? id) {
        if (id == null) {
            return null;
        }

        return id_to_app[id];
    }

    public GLib.DesktopAppInfo? lookup_startup_wmclass (string? wm_class) {
        if (wm_class == null) {
            return null;
        }

        unowned var id = startup_wm_class_to_id[wm_class];
        if (id == null) {
            return null;
        }

        return id_to_app[id];
    }
}
