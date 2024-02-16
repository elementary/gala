/*
 * Copyright 2016 Santiago León
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.KeyboardManager : Object {
    private const string[] BLOCKED_OPTIONS = {
        "grp:alt_caps_toggle", "grp:alt_shift_toggle", "grp:alt_space_toggle",
        "grp:shifts_toggle", "grp:caps_toggle", "grp:ctrl_alt_toggle",
        "grp:ctrl_shift_toggle", "grp:shift_caps_toggle"
    };

    private static KeyboardManager? instance;
    private static VariantType sources_variant_type;
    private static GLib.Settings settings;

    public unowned Meta.Display display { construct; private get; }

    public static void init (Meta.Display display) {
        if (instance != null) {
            return;
        }

        instance = new KeyboardManager (display);

        display.modifiers_accelerator_activated.connect ((display) => KeyboardManager.handle_modifiers_accelerator_activated (display, false));
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

        set_keyboard_layout (settings, "sources"); // Update the list of layouts
        set_keyboard_layout (settings, "current"); // Set current layout
    }

    private KeyboardManager (Meta.Display display) {
        Object (display: display);
    }

    [CCode (instance_pos = -1)]
    public static bool handle_modifiers_accelerator_activated (Meta.Display display, bool backward) {
#if HAS_MUTTER46
        display.get_compositor ().backend.ungrab_keyboard (display.get_current_time ());
#else
        display.ungrab_keyboard (display.get_current_time ());
#endif

        var sources = settings.get_value ("sources");
        if (!sources.is_of_type (sources_variant_type)) {
            return true;
        }

        var n_sources = (uint) sources.n_children ();
        if (n_sources < 2) {
            return true;
        }

        var current = settings.get_uint ("current");

        if (!backward) {
            settings.set_uint ("current", (current + 1) % n_sources);
        } else {
            settings.set_uint ("current", (current - 1) % n_sources);
        }

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

            if (layouts.length == 0) {
                layouts = { "us" };
                variants = { "" };
            }

            string[] xkb_options = {};
            if (layouts.length == 1) {
                foreach (unowned var option in settings.get_strv ("xkb-options")) {
                    if (!(option in BLOCKED_OPTIONS)) {
                        xkb_options += option;
                    }
                }
            } else {
                xkb_options = settings.get_strv ("xkb-options");
            }

            var layout = string.joinv (",", layouts);
            var variant = string.joinv (",", variants);
            var options = string.joinv (",", xkb_options);

#if HAS_MUTTER46
            //TODO: add model support
            display.get_context ().get_backend ().set_keymap (layout, variant, options, "");
#else
            display.get_context ().get_backend ().set_keymap (layout, variant, options);
#endif
        } else if (key == "current") {
            display.get_context ().get_backend ().lock_layout_group (settings.get_uint ("current"));
        }
    }
}
