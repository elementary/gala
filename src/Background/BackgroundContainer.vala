/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 *                         2013 Tom Beckmann
 *                         2013 Rico Tzschichholz
 */

public class Gala.BackgroundContainer : Meta.BackgroundGroup, Gala.BackgroundContainerInterface {
    public signal void show_background_menu (int x, int y);

    public WindowManager wm { get; construct; }

    public BackgroundContainer (WindowManager wm) {
        Object (wm: wm);
    }

    construct {
        unowned var monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update);

        reactive = true;
        button_release_event.connect ((event) => {
            float x, y;
            event.get_coords (out x, out y);
            if (event.get_button () == Clutter.Button.SECONDARY) {
                show_background_menu ((int)x, (int)y);
            }
        });

        set_black_background (true);
        update ();
    }

    ~BackgroundContainer () {
        unowned var monitor_manager = wm.get_display ().get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.disconnect (update);
    }

    public void set_black_background (bool black) {
        set_background_color (black ? Clutter.Color.from_string ("Black") : null);
    }

    private void update () {
        foreach (unowned var child in get_children ()) {
            var bg_manager = (BackgroundManager) child;
            bg_manager.changed.disconnect (background_changed);
        }

        destroy_all_children ();

        for (var i = 0; i < wm.get_display ().get_n_monitors (); i++) {
            var background = new BackgroundManager (wm, i);
            insert_child_at_index (background, i);

            background.changed.connect (background_changed);
        }
    }

    private void background_changed (BackgroundManager bg_manager) {
        changed (bg_manager.monitor_index);
    }
}
