/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.ColorblindFiltersManager : Object {
    private const string EFFECT_NAME = "colorblindness-filter";
    private const string TRANSITION_NAME = "strength-transition";

    private static ColorblindFiltersManager instance;
    private static GLib.Settings settings;
    public WindowManager wm { get; construct; }

    public static void init (WindowManager wm) {
        if (instance != null) {
            return;
        }

        instance = new ColorblindFiltersManager (wm);
    }

    private ColorblindFiltersManager (WindowManager wm) {
        Object (wm: wm);
    }

    static construct {
        settings = new GLib.Settings ("io.elementary.desktop.wm.accessibility");
    }

    construct {
        settings.changed["colorblind-correction-filter"].connect (() => load_filter ());
        settings.changed["colorblind-correction-filter-strength"].connect (() => load_filter ());
        load_filter (true);
    }

    private void load_filter (bool initial = false) {
        if (initial) {
            // When gala launches and there is an effect active, it shouldn't be faded in
            var filter_variant = settings.get_enum ("colorblind-correction-filter");
            var strength = settings.get_double ("colorblind-correction-filter-strength");
            if (filter_variant != 0 && strength != 0) {
                var new_effect = new ColorblindCorrectionEffect (filter_variant, strength);
                wm.stage.add_effect_with_name (EFFECT_NAME, new_effect);
            }
        } else {
            // Fade out applied effects
            var effects = wm.stage.get_effects ();
            foreach (unowned var _effect in effects) {
                if (_effect.name == EFFECT_NAME) {
                    var effect = (ColorblindCorrectionEffect) _effect;

                    // Since you can't add a transition to an effect
                    // add it to a dummy actor and bind one of its properties to the effect

                    // stop transition (if there is one in progress)
                    if (effect.dummy_actor != null) {
                        effect.dummy_actor.destroy ();
                    }

                    // create a new transition
                    var transition = new Clutter.PropertyTransition ("scale_x") {
                        duration = 1000, // TODO: Maybe use some constant?
                        progress_mode = EASE_OUT_QUAD,
                        remove_on_complete = true
                    };
                    transition.set_from_value (effect.strength);
                    transition.set_to_value (0.0);

                    // create a dummy actor and bind its `scale_x` to effect's `strength`
                    effect.dummy_actor = new Clutter.Actor () {
                        visible = false
                    };
                    wm.ui_group.add_child (effect.dummy_actor);
                    effect.dummy_actor.bind_property ("scale_x", effect, "strength");

                    transition.completed.connect (() => {
                        effect.dummy_actor.destroy ();
                        wm.stage.remove_effect (effect);
                    });

                    effect.dummy_actor.add_transition (TRANSITION_NAME, transition);
                }
            }

            // Apply a new filter
            var filter_variant = settings.get_enum ("colorblind-correction-filter");
            var strength = settings.get_double ("colorblind-correction-filter-strength");
            if (filter_variant != 0 && strength != 0) {
                var new_effect = new ColorblindCorrectionEffect (filter_variant, 0.0);
                wm.stage.add_effect_with_name (EFFECT_NAME, new_effect);

                // Transition new effect in the same way
                var transition = new Clutter.PropertyTransition ("scale_x") {
                    duration = 1000, // TODO: Maybe use some constant?
                    progress_mode = EASE_OUT_QUAD,
                    remove_on_complete = true
                };
                transition.set_from_value (0.0);
                transition.set_to_value (1.0);

                new_effect.dummy_actor = new Clutter.Actor () {
                    visible = false
                };
                wm.ui_group.add_child (new_effect.dummy_actor);
                new_effect.dummy_actor.bind_property ("scale_x", new_effect, "strength");

                transition.completed.connect (() => {
                    new_effect.dummy_actor.destroy ();
                });

                new_effect.dummy_actor.add_transition (TRANSITION_NAME, transition);
            }
        }
    }
}
