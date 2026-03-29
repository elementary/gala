/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2013 Tom Beckmann
 *                         2013 Rico Tzschichholz
 *                         2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.BackgroundContainer : Meta.BackgroundGroup {
    public signal void changed ();
    public signal void show_background_menu (int x, int y);

    public Meta.Display display { get; construct; }

    public BackgroundContainer (Meta.Display display) {
        Object (display: display);
    }

    construct {
        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update);

        reactive = true;
        button_release_event.connect ((event) => {
            float x, y;
            event.get_coords (out x, out y);
            if (event.get_button () == Clutter.Button.SECONDARY) {
                show_background_menu ((int)x, (int)y);
            }

            return Source.CONTINUE;
        });

#if HAS_MUTTER47
        background_color = Cogl.Color.from_string ("#000000");
#else
        background_color = Clutter.Color.from_string ("Black");
#endif

        update ();
    }

    ~BackgroundContainer () {
        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.disconnect (update);
    }

    private void update () {
        var reference_child = (get_child_at_index (0) as BackgroundManager);
        if (reference_child != null)
            reference_child.changed.disconnect (background_changed);

        destroy_all_children ();

        for (var i = 0; i < display.get_n_monitors (); i++) {
            var background = new BackgroundManager (display, i);

            add_child (background);

            if (i == 0)
                background.changed.connect (background_changed);
        }
    }

    private void background_changed () {
        changed ();
    }
}
