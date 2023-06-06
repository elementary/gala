/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Gala.FilterManager : Object {
    private const string TRANSITION_NAME = "strength-transition";
    private const int TRANSITION_DURATION = 500;

    private static FilterManager instance;
    private static GLib.Settings settings;
    public WindowManager wm { get; construct; }

    public static void init (WindowManager wm) {
        if (instance != null) {
            return;
        }

        instance = new FilterManager (wm);
    }

    private FilterManager (WindowManager wm) {
        Object (wm: wm);
    }

    static construct {
        settings = new GLib.Settings ("io.elementary.desktop.wm.accessibility");
    }

    construct {
        settings.changed["colorblindness-correction-filter"].connect (update_colorblindness_filter);
        settings.changed["colorblindness-correction-filter-strength"].connect (update_colorblindness_strength);
        settings.changed["enable-monochrome-filter"].connect (update_monochrome_filter);
        settings.changed["monochrome-filter-strength"].connect (update_monochrome_strength);

        load_filters ();
    }

    private void load_filters () {
        load_colorblindness_filter ();
        load_monochrome_filter ();
    }

    private void load_colorblindness_filter () {
        // When gala launches and there is an effect active, it shouldn't be faded in
        var filter_variant = settings.get_enum ("colorblindness-correction-filter");
        var strength = settings.get_double ("colorblindness-correction-filter-strength");
        if (filter_variant != 0 && strength > 0.0) {
            wm.stage.add_effect_with_name (
                ColorblindnessCorrectionEffect.EFFECT_NAME,
                new ColorblindnessCorrectionEffect (filter_variant, strength)
            );
        }
    }

    private void update_colorblindness_filter () {
        var filter_variant = settings.get_enum ("colorblindness-correction-filter");
        var strength = settings.get_double ("colorblindness-correction-filter-strength");

        // Fade out applied effects
        foreach (unowned var _effect in wm.stage.get_effects ()) {
            if (_effect is ColorblindnessCorrectionEffect) {
                unowned var effect = (ColorblindnessCorrectionEffect) _effect;

                if (effect.mode == filter_variant) {
                    continue;
                }

                // Since you can't add a transition to an effect
                // add it to a transition actor and bind one of its properties to the effect

                // stop transition (if there is one in progress)
                if (effect.transition_actor != null) {
                    effect.transition_actor.destroy ();
                }

                // create a new transition
                var transition = new Clutter.PropertyTransition ("scale_x") {
                    duration = TRANSITION_DURATION,
                    progress_mode = Clutter.AnimationMode.LINEAR,
                    remove_on_complete = true
                };
                transition.set_from_value (effect.strength);
                transition.set_to_value (0.0);

                // create a transition actor and bind its `scale_x` to effect's `strength`
                effect.transition_actor = new Clutter.Actor () {
                    visible = false
                };
                wm.ui_group.add_child (effect.transition_actor);
                effect.transition_actor.bind_property ("scale_x", effect, "strength");

                transition.completed.connect (() => {
                    effect.transition_actor.destroy ();
                    wm.stage.remove_effect (effect);
                });

                effect.transition_actor.add_transition (TRANSITION_NAME, transition);
            }
        }

        // Apply a new filter
        if (filter_variant == 0 || strength == 0.0) {
            return;
        }

        var new_effect = new ColorblindnessCorrectionEffect (filter_variant, 0.0);
        wm.stage.add_effect_with_name (ColorblindnessCorrectionEffect.EFFECT_NAME, new_effect);

        // Transition new effect in the same way
        var new_transition = new Clutter.PropertyTransition ("scale_x") {
            duration = TRANSITION_DURATION,
            progress_mode = Clutter.AnimationMode.LINEAR,
            remove_on_complete = true
        };
        new_transition.set_from_value (0.0);
        new_transition.set_to_value (strength);

        new_effect.transition_actor = new Clutter.Actor () {
            visible = false
        };
        wm.ui_group.add_child (new_effect.transition_actor);
        new_effect.transition_actor.bind_property ("scale_x", new_effect, "strength");

        new_transition.completed.connect (() => {
            new_effect.transition_actor.destroy ();
        });

        new_effect.transition_actor.add_transition (TRANSITION_NAME, new_transition);
    }

    private void update_colorblindness_strength () {
        var filter_variant = settings.get_enum ("colorblindness-correction-filter");
        var strength = settings.get_double ("colorblindness-correction-filter-strength");

        foreach (unowned var _effect in wm.stage.get_effects ()) {
            if (_effect is ColorblindnessCorrectionEffect) {
                unowned var effect = (ColorblindnessCorrectionEffect) _effect;

                if (effect.mode != filter_variant) {
                    continue;
                }

                // stop transition (if there is one in progress)
                if (effect.transition_actor != null) {
                    effect.transition_actor.destroy ();
                }

                // create a new transition
                var transition = new Clutter.PropertyTransition ("scale_x") {
                    duration = TRANSITION_DURATION,
                    progress_mode = Clutter.AnimationMode.LINEAR,
                    remove_on_complete = true
                };
                transition.set_from_value (effect.strength);
                transition.set_to_value (strength);

                // create a transition actor and bind its `scale_x` to effect's `strength`
                effect.transition_actor = new Clutter.Actor () {
                    visible = false
                };
                wm.ui_group.add_child (effect.transition_actor);
                effect.transition_actor.bind_property ("scale_x", effect, "strength");

                transition.completed.connect (() => {
                    effect.transition_actor.destroy ();
                });

                effect.transition_actor.add_transition (TRANSITION_NAME, transition);

                return;
            }
        }
    }

    private void load_monochrome_filter () {
        // When gala launches and there is an effect active, it shouldn't be faded in
        var enable = settings.get_boolean ("enable-monochrome-filter");
        var strength = settings.get_double ("monochrome-filter-strength");
        if (enable && strength > 0.0) {
            wm.stage.add_effect_with_name (
                MonochromeEffect.EFFECT_NAME,
                new MonochromeEffect (strength)
            );
        }
    }

    private void update_monochrome_filter () {
        var enabled = settings.get_boolean ("enable-monochrome-filter");
        var strength = settings.get_double ("monochrome-filter-strength");
        unowned var effect = (MonochromeEffect) wm.stage.get_effect (MonochromeEffect.EFFECT_NAME);

        if ((effect != null) == enabled) {
            return;
        }

        // Fade out applied effects
        if (effect != null) {
            // Since you can't add a transition to an effect
            // add it to a transition actor and bind one of its properties to the effect

            // stop transition (if there is one in progress)
            if (effect.transition_actor != null) {
                effect.transition_actor.destroy ();
            }

            // create a new transition
            var transition = new Clutter.PropertyTransition ("scale_x") {
                duration = TRANSITION_DURATION,
                progress_mode = Clutter.AnimationMode.LINEAR,
                remove_on_complete = true
            };
            transition.set_from_value (effect.strength);
            transition.set_to_value (0.0);

            // create a transition actor and bind its `scale_x` to effect's `strength`
            effect.transition_actor = new Clutter.Actor () {
                visible = false
            };
            wm.ui_group.add_child (effect.transition_actor);
            effect.transition_actor.bind_property ("scale_x", effect, "strength");

            transition.completed.connect (() => {
                effect.transition_actor.destroy ();
                wm.stage.remove_effect (effect);
            });

            effect.transition_actor.add_transition (TRANSITION_NAME, transition);
        }

        // Apply a new filter
        if (!enabled || strength == 0.0) {
            return;
        }

        var new_effect = new MonochromeEffect (0.0);
        wm.stage.add_effect_with_name (MonochromeEffect.EFFECT_NAME, new_effect);

        // Transition new effect in the same way
        var new_transition = new Clutter.PropertyTransition ("scale_x") {
            duration = TRANSITION_DURATION,
            progress_mode = Clutter.AnimationMode.LINEAR,
            remove_on_complete = true
        };
        new_transition.set_from_value (0.0);
        new_transition.set_to_value (strength);

        new_effect.transition_actor = new Clutter.Actor () {
            visible = false
        };
        wm.ui_group.add_child (new_effect.transition_actor);
        new_effect.transition_actor.bind_property ("scale_x", new_effect, "strength");

        new_transition.completed.connect (() => {
            new_effect.transition_actor.destroy ();
        });

        new_effect.transition_actor.add_transition (TRANSITION_NAME, new_transition);
    }

    private void update_monochrome_strength () {
        var strength = settings.get_double ("monochrome-filter-strength");

        unowned var effect = (MonochromeEffect) wm.stage.get_effect (MonochromeEffect.EFFECT_NAME);

        // stop transition (if there is one in progress)
        if (effect.transition_actor != null) {
            effect.transition_actor.destroy ();
        }

        // create a new transition
        var transition = new Clutter.PropertyTransition ("scale_x") {
            duration = TRANSITION_DURATION,
            progress_mode = Clutter.AnimationMode.LINEAR,
            remove_on_complete = true
        };
        transition.set_from_value (effect.strength);
        transition.set_to_value (strength);

        // create a transition actor and bind its `scale_x` to effect's `strength`
        effect.transition_actor = new Clutter.Actor () {
            visible = false
        };
        wm.ui_group.add_child (effect.transition_actor);
        effect.transition_actor.bind_property ("scale_x", effect, "strength");

        transition.completed.connect (() => {
            effect.transition_actor.destroy ();
        });

        effect.transition_actor.add_transition (TRANSITION_NAME, transition);
    }
}
