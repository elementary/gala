//
//  Copyright (C) 2016 Santiago León
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
    public class KeyboardManager : Object {
        private static KeyboardManager? instance;
        private static VariantType sources_variant_type;
        private static GLib.Settings settings;

        public static void init (Meta.Display display) {
            if (instance != null) {
                return;
            }

            instance = new KeyboardManager ();

            display.modifiers_accelerator_activated.connect (instance.handle_modifiers_accelerator_activated);
        }

        static construct {
            sources_variant_type = new VariantType ("a(ss)");

            var schema = GLib.SettingsSchemaSource.get_default ().lookup ("org.gnome.desktop.input-sources", true);
            if (schema == null) {
                critical ("org.gnome.desktop.input-sources not found.");
            }

            settings = new GLib.Settings.full (schema, null, null);
        }

        construct {
            settings.changed.connect (set_keyboard_layout);

            set_keyboard_layout (settings, "sources"); // Update layouts
        }

        [CCode (instance_pos = -1)]
        private bool handle_modifiers_accelerator_activated (Meta.Display display) {
            display.ungrab_keyboard (display.get_current_time ());

            var sources = settings.get_value ("sources");
            if (!sources.is_of_type (sources_variant_type)) {
                return true;
            }

            var n_sources = (uint) sources.n_children ();
            if (n_sources < 2) {
                return true;
            }

            var current = settings.get_uint ("current");
            settings.set_uint ("current", (current + 1) % n_sources);

            return true;
        }

        [CCode (instance_pos = -1)]
        private void set_keyboard_layout (GLib.Settings settings, string key) {
            if (key == "sources" || key == "xkb-options") {
                string[] layouts = {}, variants = {};

                var sources = settings.get_value ("sources");
                if (!sources.is_of_type (sources_variant_type)) {
                    return;
                }
    
                for (int i = 0; i < sources.n_children (); i++) {
                    unowned string? type = null, name = null;
                    sources.get_child (i, "(&s&s)", out type, out name);
    
                    if (type == "xkb") {
                        string[] arr = name.split ("+", 2);
                        layouts += arr[0];
                        variants += arr[1] ?? "";
    
                    }
                }
    
                var xkb_options = settings.get_strv ("xkb-options");
    
                var layout = string.joinv (",", layouts);
                var variant = string.joinv (",", variants);
                var options = string.joinv (",", xkb_options);

                Meta.Backend.get_backend ().set_keymap (layout, variant, options);
            } else if (key == "current") {
                Meta.Backend.get_backend ().lock_layout_group (settings.get_uint ("current"));
            }
        }
    }
}
