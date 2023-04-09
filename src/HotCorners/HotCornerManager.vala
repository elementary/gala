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

    private GLib.GenericArray<HotCorner> hot_corners;

    public HotCornerManager (WindowManager wm, GLib.Settings behavior_settings) {
        Object (wm: wm, behavior_settings: behavior_settings);

        hot_corners = new GLib.GenericArray<HotCorner> ();
        behavior_settings.changed.connect (configure);
        unowned var monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (configure);
    }

    public void configure () {
        unowned Meta.Display display = wm.get_display ();

        if (display.get_n_monitors () == 0) {
            return;
        }

        var primary = display.get_primary_monitor ();
        var geometry = display.get_monitor_geometry (primary);
        var scale = display.get_monitor_scale (primary);

        remove_all_hot_corners ();
        add_hotcorner (geometry.x, geometry.y, scale, HotCorner.POSITION_TOP_LEFT);
        add_hotcorner (geometry.x + geometry.width, geometry.y, scale, HotCorner.POSITION_TOP_RIGHT);
        add_hotcorner (geometry.x, geometry.y + geometry.height, scale, HotCorner.POSITION_BOTTOM_LEFT);
        add_hotcorner (geometry.x + geometry.width, geometry.y + geometry.height, scale, HotCorner.POSITION_BOTTOM_RIGHT);

        this.on_configured ();
    }

    private void remove_all_hot_corners () {
        hot_corners.@foreach ((hot_corner) => {
            hot_corner.destroy_barriers ();
        });

        hot_corners.remove_range (0, hot_corners.length);
    }

    private void add_hotcorner (float x, float y, float scale, string hot_corner_position) {
        var action_type = (ActionType) behavior_settings.get_enum (hot_corner_position);
        if (action_type == ActionType.NONE) {
            return;
        }

        unowned Meta.Display display = wm.get_display ();
        var hot_corner = new HotCorner (display, (int) x, (int) y, scale, hot_corner_position);

        hot_corner.trigger.connect (() => {
            if (action_type == ActionType.CUSTOM_COMMAND) {
                run_custom_action (hot_corner_position);
            } else {
                wm.perform_action (action_type);
            }
        });

        hot_corners.add (hot_corner);
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
            foreach (unowned var part in parts) {
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
