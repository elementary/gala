/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2013 Tom Beckmann
 *                         2013 Rico Tzschichholz
 *                         2025 elementary, Inc. (https://elementary.io)
 */

public class Gala.BackgroundContainer : Meta.BackgroundGroup {
    public signal void changed ();
    public signal void show_background_menu (int monitor, int x, int y);

    public Meta.Display display { private get; construct; }

    public BackgroundContainer (Meta.Display display) {
        Object (display: display);
    }

    construct {
        unowned var monitor_manager = display.get_context ().get_backend ().get_monitor_manager ();
        monitor_manager.monitors_changed.connect (update);

#if HAS_MUTTER47
        background_color = Cogl.Color.from_string ("Black");
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
        var reference_child = (BackgroundManager) get_child_at_index (0);
        if (reference_child != null) {
            reference_child.changed.disconnect (background_changed);
        }

        destroy_all_children ();

        for (var i = 0; i < display.get_n_monitors (); i++) {
            var background = new BackgroundManager (display, i);
            add_child (background);

            background.button_release_event.connect ((__background, event) => {
                if (event.get_button () == Clutter.Button.SECONDARY) {
                    float x, y;
                    event.get_coords (out x, out y);

                    var _background = (BackgroundManager) __background;
                    show_background_menu (_background.monitor_index, (int) x, (int) y);
                }

                return Clutter.EVENT_STOP;
            });

            if (i == 0) {
                background.changed.connect (background_changed);
            }
        }
    }

    private void background_changed () {
        changed ();
    }
}
