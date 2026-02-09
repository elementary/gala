/*
 * Copyright 2016 Santiago León
 * Copyright 2023-2025 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.KeyboardManager : Object {
    private const string[] BLOCKED_OPTIONS = {
        "grp:alt_caps_toggle", "grp:alt_shift_toggle", "grp:alt_space_toggle",
        "grp:shifts_toggle", "grp:caps_toggle", "grp:ctrl_alt_toggle",
        "grp:ctrl_shift_toggle", "grp:shift_caps_toggle"
    };

    public Meta.Display display { construct; private get; }

    private GLib.Settings settings;
#if HAS_MUTTER49
    private GLib.Cancellable? cancellable = null;
#endif

    public KeyboardManager (Meta.Display display) {
        Object (display: display);
    }

    construct {
        settings = new GLib.Settings ("org.gnome.desktop.input-sources");

        on_settings_changed ("sources"); // Update the list of layouts
        on_settings_changed ("current"); // Set current layout

        settings.changed.connect (on_settings_changed);

        display.modifiers_accelerator_activated.connect (() => switch_input_source (false));

        var keybinding_settings = new GLib.Settings ("io.elementary.desktop.wm.keybindings");
        display.add_keybinding ("switch-input-source", keybinding_settings, IGNORE_AUTOREPEAT, handle_keybinding);
        display.add_keybinding ("switch-input-source-backward", keybinding_settings, IGNORE_AUTOREPEAT, handle_keybinding);
    }

    private void handle_keybinding (
        Meta.Display display, Meta.Window? window, Clutter.KeyEvent? event, Meta.KeyBinding binding
    ) {
        switch_input_source (binding.get_name ().has_suffix ("-backward"));
    }

    private bool switch_input_source (bool backward) {
#if !HAS_MUTTER50
#if HAS_MUTTER46
        display.get_compositor ().backend.ungrab_keyboard (display.get_current_time ());
#else
        display.ungrab_keyboard (display.get_current_time ());
#endif
#endif

        var sources = settings.get_value ("sources");

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

    private void on_settings_changed (string key) {
        unowned var backend = display.get_context ().get_backend ();

#if HAS_MUTTER50
        if (key == "sources" || key == "xkb-options" || key == "xkb-model" || key == "current") {
#else
        if (key == "sources" || key == "xkb-options" || key == "xkb-model") {
#endif
            string[] layouts = {}, variants = {};

            var sources = settings.get_value ("sources");
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

#if HAS_MUTTER49
            if (cancellable != null) {
                cancellable.cancel ();
                cancellable = new GLib.Cancellable ();
            }

#if HAS_MUTTER50
            var description = new Meta.KeymapDescription.from_rules (settings.get_string ("xkb-model"), layout, variant, options, layouts, layouts);
            backend.set_keymap_async.begin (description, settings.get_uint ("current"), cancellable, (obj, res) => {
#else
            backend.set_keymap_async.begin (layout, variant, options, settings.get_string ("xkb-model"), cancellable, (obj, res) => {
#endif
                try {
                    ((Meta.Backend) obj).set_keymap_async.end (res);
                } catch (Error e) {
                    if (e is GLib.IOError.CANCELLED) {
                        // ignore
                    } else {
                        cancellable = null;
                    }
                }
            });
#elif HAS_MUTTER46
            backend.set_keymap (layout, variant, options, settings.get_string ("xkb-model"));
#else
            backend.set_keymap (layout, variant, options);
#endif
#if !HAS_MUTTER50
        } else if (key == "current") {
#if HAS_MUTTER49
            if (cancellable != null) {
                cancellable.cancel ();
                cancellable = new GLib.Cancellable ();
            }

            backend.set_keymap_layout_group_async.begin (settings.get_uint ("current"), cancellable, (obj, res) => {
                try {
                    ((Meta.Backend) obj).set_keymap_layout_group_async.end (res);
                } catch (Error e) {
                    if (e is GLib.IOError.CANCELLED) {
                        // ignore
                    } else {
                        cancellable = null;
                    }
                }
            });
#else
            backend.lock_layout_group (settings.get_uint ("current"));
#endif
#endif
        }
    }
}
