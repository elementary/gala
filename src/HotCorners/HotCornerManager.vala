/*
 * Copyright 2021 elementary, Inc (https://elementary.io)
 *           2021 José Expósito <jose.exposito89@gmail.com>
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

public class Gala.HotCornerManager : Object {
    public signal void on_configured ();

    public WindowManager wm { get; construct; }
    public GLib.Settings behavior_settings { get; construct; }

    public HotCornerManager (WindowManager wm, GLib.Settings behavior_settings) {
        Object (wm: wm, behavior_settings: behavior_settings);

        behavior_settings.changed.connect (configure);
        Meta.MonitorManager.@get ().monitors_changed.connect (configure);
    }

    public void configure () {
        unowned Meta.Display display = wm.get_display ();
        var geometry = display.get_monitor_geometry (display.get_primary_monitor ());

        add_hotcorner (geometry.x, geometry.y, "hotcorner-topleft");
        add_hotcorner (geometry.x + geometry.width - 1, geometry.y, "hotcorner-topright");
        add_hotcorner (geometry.x, geometry.y + geometry.height - 1, "hotcorner-bottomleft");
        add_hotcorner (geometry.x + geometry.width - 1, geometry.y + geometry.height - 1, "hotcorner-bottomright");

        this.on_configured ();
    }

    private void add_hotcorner (float x, float y, string key) {
        unowned Clutter.Actor? stage = wm.get_display ().get_stage ();
        return_if_fail (stage != null);

        var action = (ActionType) behavior_settings.get_enum (key);
        Clutter.Actor? hot_corner = stage.find_child_by_name (key);

        if (action == ActionType.NONE) {
            if (hot_corner != null)
                stage.remove_child (hot_corner);
            return;
        }

        // if the hot corner already exists, just reposition it, create it otherwise
        if (hot_corner == null) {
            hot_corner = new Clutter.Actor ();
            hot_corner.width = 1;
            hot_corner.height = 1;
            hot_corner.opacity = 0;
            hot_corner.reactive = true;
            hot_corner.name = key;

            stage.add_child (hot_corner);

            hot_corner.enter_event.connect ((actor, event) => {
                var hot_corner_name = actor.name;
                var action_type = (ActionType) behavior_settings.get_enum (hot_corner_name);

                if (action_type == ActionType.CUSTOM_COMMAND) {
                    run_custom_action (hot_corner_name);
                } else {
                    wm.perform_action (action_type);
                }
                return false;
            });
        }

        hot_corner.x = x;
        hot_corner.y = y;
    }

    private void run_custom_action (string hot_corner_position) {
        string command = "";
        var line = behavior_settings.get_string ("hotcorner-custom-command");
        if (line == "")
            return;

        var parts = line.split (";;");
        // keep compatibility to old version where only one command was possible
        if (parts.length == 1) {
            command = line;
        } else {
            // find specific actions
            foreach (var part in parts) {
                var details = part.split (":");
                if (details[0] == hot_corner_position) {
                    command = details[1];
                }
            }
        }

        try {
            Process.spawn_command_line_async (command);
        } catch (Error e) {
            warning (e.message);
        }
    }
}
