//
//  Copyright (C) 2013 Tom Beckmann, Rico Tzschichholz
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

namespace Gala {
    public class BackgroundContainer : Meta.BackgroundGroup {
        public signal void changed ();
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
            var reference_child = (get_child_at_index (0) as BackgroundManager);
            if (reference_child != null)
                reference_child.changed.disconnect (background_changed);

            destroy_all_children ();

            for (var i = 0; i < wm.get_display ().get_n_monitors (); i++) {
                var background = new BackgroundManager (wm, i);

                add_child (background);

                if (i == 0)
                    background.changed.connect (background_changed);
            }
        }

        private void background_changed () {
            changed ();
        }
    }
}
